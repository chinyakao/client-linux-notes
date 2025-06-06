# linux_kernel_driver_training
## 1. Repository Structure

```
linux-kernel-driver-training/
├── foundation/
│   ├── kernel_modules/
│   ├── char_driver_intro/
│   ├── char_driver_ioctl/
│   ├── usb_driver/
│   ├── pci_driver/
│   ├── block_driver/
│   ├── net_driver/
│   └── ...
├── laptop_devices/
│   ├── graphics_drm/
│   ├── audio_alsa/
│   ├── input_evdev/
│   ├── backlight/
│   └── ...
├── advanced_features/
│   ├── wireless_mac80211/
│   ├── camera_v4l2/
│   ├── power_management/
│   ├── firmware_loading/
│   └── ...
├── common_libs_and_tools/
│   ├── test_utils/
│   ├── tracing_scripts/
│   └── qemu_configs/
└── README.md

```

---

## 2. Weekly Learning Checklist

### Week 1: Kernel Module Basics

- [ ]  Install kernel headers and toolchains
- [ ]  Write and compile a hello_world module
- [ ]  Load/unload with `insmod` and `rmmod`
- [ ]  Inspect logs via `dmesg`
- [ ]  Exercise: Modify the message output

### Week 2: Char Driver Intro

- [ ]  Implement a basic char device using `register_chrdev`
- [ ]  Implement `open`, `read`, `write`
- [ ]  Understand user/kernel buffer operations
- [ ]  Exercise: Write a user-space test program

### Week 3: Char Driver with IOCTL

- [ ]  Implement ioctl handling in driver
- [ ]  Define command macros with `_IO`, `_IOR`, `_IOW`
- [ ]  Exercise: Create user app to send/receive data via ioctl

### Week 4: USB Driver

- [ ]  Use `usb_driver` and `usb_device_id`
- [ ]  Implement `probe` and `disconnect`
- [ ]  Send/receive USB bulk messages
- [ ]  Exercise: Detect specific USB device via your driver

### Week 5: PCI Driver

- [ ]  Use `pci_register_driver`
- [ ]  Map BARs using `ioremap`
- [ ]  Perform read/write with `readl/writel`
- [ ]  Exercise: Simulate a PCI device using QEMU

### Week 6: Block Driver

- [ ]  Implement a virtual block device
- [ ]  Understand `request_queue` and `gendisk`
- [ ]  Format and mount the device using `mkfs`, `mount`
- [ ]  Exercise: Create a RAM disk module

### Week 7: Net Driver

- [ ]  Register `net_device`
- [ ]  Implement `ndo_start_xmit`
- [ ]  Use `ping` or `tcpdump` to test packets
- [ ]  Exercise: Build a loopback-like net driver

---

## 3. README Template for Each Subsystem

```markdown
# [Module Name] - Linux Kernel Driver

## Overview
Short description of what this driver/module does.

## Files
- `driver.c` – The kernel module
- `Makefile` – Build instructions
- `test_app.c` – User space test program

## Build Instructions
```bash
make
sudo insmod driver.ko
sudo rmmod driver

```

## Test Instructions

```bash
gcc test_app.c -o test_app
sudo ./test_app

```

## Expected Output

Describe the expected behavior or result here.

## Notes

- Kernel version: [e.g. 6.8.x]
- Dependencies: [list required packages or modules]
- Device access: e.g. `/dev/your_driver`

## References

[List of useful links or kernel docs]

```

```