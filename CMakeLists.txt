cmake_minimum_required(VERSION 3.20)
set(PSXRECOMP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/psxrecomp" CACHE PATH
    "Path to psxrecomp")
if(NOT EXISTS "${PSXRECOMP_ROOT}/runtime/runtime.cmake")
    message(FATAL_ERROR
        "PSXRecomp runtime is missing: ${PSXRECOMP_ROOT}/runtime/runtime.cmake\n"
        "This project expects the psxrecomp framework checkout at ${PSXRECOMP_ROOT}.\n"
        "Run: git submodule update --init --recursive\n"
        "If psxrecomp/ is not a submodule, set -DPSXRECOMP_ROOT=<path-to-psxrecomp>.")
endif()

project(wwf_war_zone LANGUAGES C CXX)

# --- Opt-in product surfaces (OFF by default in the framework) -------------
# Scaffold prompts / flags fill these. Without recomp-ui, PSX_RECOMP_UI is OFF.
# Setup-host CI requires WIZARD_CMAKE_BLOCK / ENABLE_SETUP_WIZARD (FORCE_SETUP_HOST
# alone does not open first-run / Generate & rebuild).
set(PSX_RECOMP_UI ON CACHE BOOL "Use recomp-ui" FORCE)
# Netplay (PS1B-278): on for titles with two or more players.
if(EXISTS "${PSXRECOMP_ROOT}/lib/recomp-net/CMakeLists.txt")
    set(PSX_NETPLAY ON CACHE BOOL "Netplay" FORCE)
endif()
set(PSX_SETUP_WIZARD ON CACHE BOOL "Enable owned-input setup" FORCE)
set(PSXRECOMP_BIOS_STEMS "SCPH1001" CACHE STRING "Bound retail BIOS" FORCE)
set(PSXRECOMP_BIOS_STEM "SCPH1001" CACHE STRING "Accepted BIOS" FORCE)
set(PSXRECOMP_BIOS_PROFILE "${PSXRECOMP_ROOT}/bios/SCPH1001.toml" CACHE FILEPATH "Accepted BIOS" FORCE)
include("${PSXRECOMP_ROOT}/runtime/runtime.cmake")

# This project's own mod catalog. The FRAMEWORK stages it -- together with its
# builtin psx.* packages -- into <exe-dir>/mods/bundled, and refuses to
# configure if a catalog exists here but is not declared. Never copy it by
# hand: five titles did, and framework 4cc04be3's rename of the staged
# directory broke all five silently (bead beads-eio.3.101).
set(PSX_PRELOADED_MODS "${CMAKE_CURRENT_SOURCE_DIR}/mods/preloaded")
if(NOT IS_DIRECTORY "${PSX_PRELOADED_MODS}")
    set(PSX_PRELOADED_MODS "NONE")
endif()

psxrecomp_add_game_runtime(psx-runtime
    ENABLE_NETPLAY_IF_PRESENT
    NETPLAY_LOBBY_URL "ws://netplay.retcomm.net:8765"
    PRELOADED_MODS_DIR "${PSX_PRELOADED_MODS}"


    ENABLE_SETUP_WIZARD
    EXE_NAME "wwf_war_zone"
    WINDOW_TITLE "WWF War Zone"
    DEFAULT_GAME_CONFIG_PATH "game.toml"
    MAX_PLAYERS 2


    GEN_MARKER "generated/SLUS_004.95_dispatch.c"
    GEN_FULL_GLOB "generated/SLUS_004.95_full_*.c"
    CODEGEN_SETUP_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/codegen_setup.c"
)

# Stage runtime configs next to the exe for direct build/ launches. Only copy
# files that exist — never fail POST_BUILD when game_options.toml is absent.
foreach(_PSX_RUNTIME_CONFIG game.toml game_options.toml)
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${_PSX_RUNTIME_CONFIG}")
        add_custom_command(TARGET psx-runtime POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CMAKE_CURRENT_SOURCE_DIR}/${_PSX_RUNTIME_CONFIG}"
                "$<TARGET_FILE_DIR:psx-runtime>/${_PSX_RUNTIME_CONFIG}"
            COMMENT "Staging ${_PSX_RUNTIME_CONFIG}"
            VERBATIM)
    endif()
endforeach()
