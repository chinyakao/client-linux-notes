---
title: "Intel DPTF"
parent: "Thermal"
grand_parent: "English"
nav_order: 3
lang: en
---

# Intel DPTF

## Intel DPTF in the Linux kernel

The Linux kernel documentation defines DPTF as:

> *"DPTF is a platform level hardware/software solution… some parts implemented in firmware using ACPI, kernel drivers expose interfaces to user space"* [\[docs.kernel.org\]](https://docs.kernel.org/driver-api/thermal/intel_dptf.html)

The whole DPTF architecture includes:

    ┌──────────────────────────────┐
    │ Firmware / BIOS               │
    │  - ACPI DPTF tables (_TRT…)   │
    └──────────────┬───────────────┘
                   │
    ┌──────────────▼───────────────┐
    │ Kernel drivers                │
    │  - INT3400 / INTC1040 etc.    │
    │  - thermal / power interfaces│
    └──────────────┬───────────────┘
                   │
    ┌──────────────▼───────────────┐
    │ User space policy engine      │
    │  - ipf_ufd                    │
    │  - DptfPolicy*.so             │
    └──────────────────────────────┘

**GitHub `intel/dptf` only covers the bottom layer (the user space policy and ESIF framework).**

## `intel/dptf` on GitHub
In the repo README, Intel describes it like this:

> *"Intel (R) Dynamic Tuning for Chromium OS"*
> *"DPTF user space daemon relies on INT340X thermal drivers and DPTF ACPI objects"* [\[github.com\]](https://github.com/intel/dptf), [\[github.com\]](https://github.com/intel/dptf/blob/master/README.txt)

Key points:

*   It is a **user space daemon / framework**.
*   It depends on:
    *   **DPTF ACPI objects in the BIOS/firmware**
    *   the **INT340x / INTC104x drivers** in the Linux kernel
*   Main target platforms:
    *   **ChromeOS**
    *   **Linux (Ubuntu and others)**

This is exactly "the user space implementation of Intel DPTF on Linux/ChromeOS".

## Intel DPTF vs. the dptf user space framework

*   **Intel DPTF as a concept**: a *platform-level power / thermal management architecture and specification*
*   **GitHub `intel/dptf`**: Intel's **open source DPTF user space framework implementation**, mainly for **Linux / ChromeOS**

> "`intel/dptf` on GitHub is **the open source user space implementation of Intel DPTF for Linux / ChromeOS**.
> It is one component of the overall Intel DPTF platform architecture, not the complete DPTF ecosystem."
