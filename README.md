<p align="center"><a href="https://alexbeavs-ps1-ports.github.io/psxrecomp-ports/"><img src="https://raw.githubusercontent.com/alexbeavs-ps1-ports/psxrecomp-ports/main/docs/assets/alexbeav-ps1-recomps-banner.png" alt="Alexbeav's PS1 Recomps" width="100%"></a></p>

# WWF War Zone

Private source preparation; no build or gameplay qualification.
Status, setup instructions and evidence: [T91](https://app.notion.com/p/3de1cf959a4c81d1bb38e5342763307e).

<!-- release-standard:bios -->
**BIOS:** SCPH-1001 (USA) retail BIOS, 524288 bytes, SHA-256 `71af94d1e47a68c11e8fdb9f8368040601514a42a5a399cda48c7d3bff1e99d3`. Supply your own dump; releases do not use OpenBIOS.
<!-- /release-standard:bios -->

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
**Framework:** `psxrecomp` and `recomp-ui` are submodules pinned to test pin F (psxrecomp `a3e5fd892`, recomp-ui `8cf5b08`). Re-point both to pin G at release (PS1B-275). CI: Woodpecker, manual runs (`.woodpecker/`).
<!-- /framework-pin -->
