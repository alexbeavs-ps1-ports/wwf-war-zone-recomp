#!/usr/bin/env bash
# Woodpecker port of the "build" job in .github/workflows/release.yml (G72, PLAT-45).
# Same steps, same psxrecomp scripts; only the GitHub-only plumbing is replaced:
#   - composite actions -> the scripts they wrap (build_emitters.sh, fetch_toolchain.sh)
#   - GITHUB_ENV        -> a temp file sourced after each helper that writes to it
#   - actions/cache     -> none (a cold build; the agents keep their workspace per run)
# Linux: runs in ubuntu:24.04 on the athena agent. Windows: runs in the agent's own
# MSYS2 MINGW64 bash on Pegasus. macOS is not built here (cross-build pending, T212).
#
# Usage: scripts/ci/woodpecker_build.sh <linux-x64|windows-x64>
# Env:   RELEASE_VERSION (default 0.0.0-ci; a proof build never publishes)
set -euo pipefail

ARTIFACT="${1:?usage: woodpecker_build.sh <linux-x64|windows-x64>}"
RELEASE_VERSION="${RELEASE_VERSION:-0.0.0-ci}"
RELEASE_VERSION="${RELEASE_VERSION#v}"
export RELEASE_VERSION CI=true CMAKE_BUILD_TYPE=Release
export GITHUB_ENV="${PWD}/.ci-env" GITHUB_OUTPUT="${PWD}/.ci-output"
: >"${GITHUB_ENV}"; : >"${GITHUB_OUTPUT}"
load_env() { if [[ -s "${GITHUB_ENV}" ]]; then set -a; . "${GITHUB_ENV}"; set +a; fi; }
step() { echo; echo "=== $*"; }

# Build parallelism: BUILD_JOBS from the pipeline, else all cores. athena sets 6: it has
# 14 GB and hung from a global OOM under clang at -j18 (PLAT-45, 2026-09-17).
JOBS="${BUILD_JOBS:-$(nproc 2>/dev/null || echo 4)}"
export CMAKE_BUILD_PARALLEL_LEVEL="${JOBS}"

case "$(uname -s)" in MINGW*|MSYS*) OS=windows ;; Linux) OS=linux ;; *) echo "unsupported host $(uname -s)"; exit 1 ;; esac

step "Pin VERSION (${RELEASE_VERSION})"
printf '%s\n' "${RELEASE_VERSION}" >VERSION

step "Record framework revisions"
bash psxrecomp/tools/ci/record_pins.sh

# Older templates (the wave2 repos, psxrecomp afe9ab2) predate these two checks;
# the GitHub workflows of those repos do not run them either.
if [[ -f psxrecomp/tools/ci/check_boot_exe.sh ]]; then
  step "Lint boot-EXE name consistency"
  bash psxrecomp/tools/ci/check_boot_exe.sh .
fi

if [[ -f tests/test_setup_exe_name.py ]]; then
  step "Check setup executable name"
  python3 tests/test_setup_exe_name.py
fi

step "Setup host mode (no game C / BIOS backends in CI)"
bash psxrecomp/tools/ci/clear_generated.sh

step "Verify Vulkan build tools"
command -v glslc; glslc --version || true
HDR=""
for c in /mingw64/include/vulkan/vulkan.h /usr/include/vulkan/vulkan.h; do
  [[ -f "${c}" ]] && { HDR="${c}"; break; }
done
[[ -n "${HDR}" ]] || { echo "ERROR: vulkan/vulkan.h not found"; exit 1; }
echo "Found ${HDR}"

step "Prefetch SDL3 source"
bash psxrecomp/tools/ci/prefetch_sdl3.sh --out-dir .cache/sdl3-src
load_env

if [[ "${OS}" == windows ]]; then
  step "Fetch portable toolchain (Windows emitters)"
  bash psxrecomp/tools/fetch_toolchain.sh --artifact "${ARTIFACT}" \
    --dl-dir .cache/toolchain-dl --out-dir .cache/toolchain-pack \
    --repo TechnicallyComputers/retcomm-toolchains
  load_env
fi

step "Build recompiler tools (emitters)"
bash psxrecomp/tools/ci/build_emitters.sh --framework psxrecomp --build-dir build-recompiler --jobs "${JOBS}"

step "Verify emitters present"
count="$(find build-recompiler -type f \( -name 'psxrecomp-game*' -o -name 'psxrecomp-bios*' \) | wc -l | tr -d ' ')"
[[ "${count}" -ge 2 ]] || { echo "ERROR: expected psxrecomp-game + psxrecomp-bios (found ${count})"; exit 1; }

step "Configure & build setup host"
EXTRA=()
if [[ "${OS}" == linux ]]; then
  [[ -z "${VULKAN_SDK:-}" && -f /usr/include/vulkan/vulkan.h ]] && export VULKAN_SDK=/usr
  if command -v ccache >/dev/null 2>&1; then
    EXTRA+=("-DCMAKE_C_COMPILER_LAUNCHER=ccache" "-DCMAKE_CXX_COMPILER_LAUNCHER=ccache")
  fi
else
  [[ -z "${VULKAN_SDK:-}" && -f /mingw64/include/vulkan/vulkan.h ]] && export VULKAN_SDK=/mingw64
  # Same as the GitHub job: the llvm-mingw toolchain must not win -L for the MSYS2 g++ link.
  unset PSXRECOMP_TOOLCHAIN_DIR TOOLCHAIN_DIR BPE_TOOLCHAIN_DIR RETCOMM_TOOLCHAIN_DIR CMAKE_PREFIX_PATH SDL3_DIR ZLIB_ROOT || true
fi
command -v glslc >/dev/null 2>&1 && EXTRA+=("-DGLSLC_EXE=$(command -v glslc)")
if [[ -n "${PSX_SDL3_SOURCE_DIR:-}" && -f "${PSX_SDL3_SOURCE_DIR}/CMakeLists.txt" ]]; then
  EXTRA+=("-DFETCHCONTENT_SOURCE_DIR_SDL3=${PSX_SDL3_SOURCE_DIR}")
fi
cmake -S . -B build-ci -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DPSXRECOMP_FORCE_SETUP_HOST=ON \
  -DPSXRECOMP_ALLOW_NO_BIOS=ON \
  -DPSX_SETUP_WIZARD=ON \
  -DPSX_GAME_VERSION="${RELEASE_VERSION}" \
  "${EXTRA[@]}" 2>&1 | tee build-ci-configure.log
grep -q 'Vulkan backend: headers' build-ci-configure.log || { echo "ERROR: CMake did not enable PSX_HAVE_VULKAN"; exit 1; }
grep -q 'PSX_HAVE_VULKAN' build-ci/build.ninja || { echo "ERROR: PSX_HAVE_VULKAN missing from compile flags"; exit 1; }
cmake --build build-ci --target psx-runtime -j"${JOBS}"
STAMP="$(find build-ci -name psx_game_version.txt -type f 2>/dev/null | head -n1 || true)"
[[ -n "${STAMP}" ]] || { echo "ERROR: missing psx_game_version.txt after build"; exit 1; }
BUILT="$(tr -d '[:space:]' <"${STAMP}")"; BUILT="${BUILT#v}"
[[ "${BUILT}" == "${RELEASE_VERSION}" ]] || { echo "ERROR: lobby pin ${BUILT} != ${RELEASE_VERSION}"; exit 1; }
echo "lobby pin ok: ${BUILT}"

step "Package setup zip"
if [[ "${OS}" == windows ]]; then
  export PSXRECOMP_RUNTIME_BIN_DIR=/mingw64/bin BPE_RUNTIME_BIN_DIR=/mingw64/bin
fi
bash scripts/package_setup_release.sh build-ci "${ARTIFACT}" build-recompiler
ls -la dist/

step "Verify zip ships the mod catalog"
ZIP="$(ls dist/*-"${ARTIFACT}".zip | head -1)"  # title prefix comes from scripts/package_setup_release.sh
MANIFESTS="$(unzip -l "${ZIP}" | grep -c 'mods/packages/.*/manifest\.toml' || true)"
echo "mod manifests in ${ZIP}: ${MANIFESTS}"
[[ "${MANIFESTS}" -ge 1 ]] || { echo "ERROR: release zip ships no mod catalog"; exit 1; }
if unzip -l "${ZIP}" | grep -q 'state\.toml'; then echo "ERROR: zip contains mods/state.toml"; exit 1; fi
if unzip -p "${ZIP}" 'mods/**/manifest.toml' 2>/dev/null | grep -Eq '^[[:space:]]*channel[[:space:]]*=[[:space:]]*"developer"'; then
  echo "ERROR: zip contains developer-channel mod packages"; exit 1
fi
sha256sum "${ZIP}"
echo "OK: ${ZIP}"
