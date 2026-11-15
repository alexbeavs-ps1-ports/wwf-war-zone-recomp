<p align="center"><a href="https://alexbeavs-ps1-ports.github.io/psxrecomp-ports/"><img src="https://raw.githubusercontent.com/alexbeavs-ps1-ports/psxrecomp-ports/main/docs/assets/alexbeav-ps1-recomps-banner.png" alt="Alexbeav's PS1 Recomps" width="100%"></a></p>

# WWF War Zone


<!-- release-standard:bios -->
**BIOS:** SCPH-1001 (USA) retail BIOS, 524288 bytes, SHA-256 `71af94d1e47a68c11e8fdb9f8368040601514a42a5a399cda48c7d3bff1e99d3`. Supply your own dump; releases do not use OpenBIOS.
<!-- /release-standard:bios -->

## Status

Latest release: v0.1.0, built on psxrecomp pin I 0.1.23.

- Packages for Windows x64, Linux x64, macOS Apple Silicon and macOS Intel passed the CI build and package checks.
- Replay check: on Windows, a build on pin I 0.1.23 played 2 of 2 recorded routes to the end without a crash. That check compares memory, not the picture, and is not a play test.
- Not claimed: full-game completion, audio fidelity or multiplayer. Setup and gameplay reports from Linux, macOS and Steam Deck are welcome.

Known issues for the current version are in its [release notes](https://github.com/alexbeavs-ps1-ports/wwf-war-zone-recomp/releases/tag/v0.1.0).

## About this project

These ports are developed by a hobbyist (a DevSecOps engineer, not a game
programmer) with substantial AI assistance. What keeps that honest: every
change is validated before it ships - boot gates, hardware-oracle A/B
comparisons (Beetle/DuckStation), deterministic replay probes, and a shared
findings registry that documents failures as carefully as successes. AI
writes most of the code; the evidence discipline decides what survives.
Bug reports welcome - expect them to be investigated the same way.

tl;dr AI writes the code, but I always test it myself before pushing

<!-- framework-pin -->
**Framework:** `psxrecomp` and `recomp-ui` are submodules pinned to psxrecomp pin I 0.1.23 (psxrecomp `578bd3b`, recomp-ui `5302f1f`).
<!-- /framework-pin -->
