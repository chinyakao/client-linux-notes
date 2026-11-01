---
title: "Intel DTT"
parent: "Thermal"
grand_parent: "English"
nav_order: 4
lang: en
---

# Intel DTT (Dynamic Tuning Technology)

> **Intel DTT is a cross-layer system:
> policy and decisions mainly live in the OS driver (IPF/DTT),
> BIOS/firmware provides the platform limits and interfaces,
> and what actually changes CPU/SoC behavior is the low-level platform power-control MMIO / mailbox / MSR.
> So saying DTT is "in the BIOS" or "in MMIO" only describes one of its layers.**

## How DTT Actually Works, Layer by Layer

We split DTT into **5 layers** (top to bottom):

    ┌─────────────────────────────┐
    │ OS / User mode              │
    │  Intel DTT / IPF service    │  ← Policy decision
    └──────────────┬──────────────┘
                   │
    ┌──────────────▼──────────────┐
    │ Kernel / Driver layer       │
    │  Intel IPF / DTT drivers    │  ← Translation layer
    └──────────────┬──────────────┘
                   │
    ┌──────────────▼──────────────┐
    │ Firmware runtime (BIOS/UEFI │
    │  + ACPI + SMU/PMC hooks)    │  ← Platform rules
    └──────────────┬──────────────┘
                   │
    ┌──────────────▼──────────────┐
    │ SoC / CPU power controller  │
    │  MMIO / mailbox / MSR       │  ← Real enforcement
    └──────────────┬──────────────┘
                   │
    ┌──────────────▼──────────────┐
    │ Hardware (CPU/GPU/VR/EC)    │
    └─────────────────────────────┘

### DTT in BIOS / Firmware

In the BIOS, DTT is mainly responsible for:

*   **The BIOS option that enables DTT:**
    > *Intel® Dynamic Tuning Technology: Enabled/Disabled* [\[asus.com\]](https://www.asus.com/support/faq/1053613/)
*   **Defining platform capabilities and limits**
    *   Power budget (PL1/PL2)
    *   Skin temperature model
    *   VR current limits
*   **ACPI / IPF tables**
    *   What the OS driver is "allowed" to tune

> ⚠️ **But the key point is:**
> **the BIOS does not keep running a tuning algorithm at runtime.**

What the BIOS does:

*   **Describes the rules**
*   **Provides the channel**
*   **Enforces safety limits and clamps**

It does not make dynamic decisions.

### DTT in the OS / Driver: Dynamic Tuning

Intel's official definition:

> *Intel DTT is system software drivers configured by OEMs to dynamically optimize performance, thermals, and battery life* [\[station-drivers.com\]](https://www.station-drivers.com/index.php/en/component/remository/Drivers/Intel/Dynamic-Tuning-Technology-%28DTT%29/Intel-Dynamic-Tuning-Technology-%28DTT%29-Version-9.0.11906.54998/lang,en-gb/)

On Windows you will see:

*   **Intel Dynamic Tuning Technology**
*   **Intel Innovation Platform Framework (IPF)**

This layer is responsible for:

*   Collecting telemetry (temperature, power, load, mode)
*   Running **policy / AI / heuristics**
*   Deciding:
    *   Whether to raise or lower PL
    *   Turbo window
    *   CPU vs GPU power sharing

**This is where "dynamic tuning" really happens.**

### DTT at the Platform Power Control (MMIO) Level

After the DTT driver makes a decision, it **does not change the CPU frequency directly**.

It goes through:

*   **SoC Power Management Controller (PMC)**
*   **Mailbox interface**
*   **MMIO registers**
*   **MSR (some legacy paths)**

to set:

*   PL1 / PL2
*   Tau
*   GT / IA power split
*   Current limits

**This layer is what really affects hardware behavior.**

> **The final effect of DTT is enforced through the platform power-control registers.**


### Why Do People Think "DTT Is in the BIOS"?

A few practical reasons:

1.  **If the BIOS does not enable it, the OS driver can do nothing**
    *   Without ACPI/IPF capabilities → the driver cannot tune anything
2.  **Part of the Embedded Controller / PMC logic lives in firmware**
    *   Some thermal / current safety clamps are always-on firmware
3.  **OEMs often describe tuning behavior as a BIOS feature**
    *   To simplify external communication

But architecturally:

> **The BIOS is the rule-maker and gatekeeper, not a runtime policy engine.**
