---
title: "apport and core dumps"
parent: "Debugging"
grand_parent: "English"
nav_order: 2
lang: en
---

# What is `apport`?
Apport is the crash reporting system of Ubuntu and other Debian-based distributions (such as Linux Mint and elementary OS). It was developed by the Ubuntu team to automatically collect diagnostic information when a program crashes and produce a report called an Apport report. The report helps developers and system administrators understand why the error happened.

- Apport is an Ubuntu-specific tool
- Installed by default on Ubuntu
- Integrated with Ubuntu's bug tracker (Launchpad)
- The `.crash` file format and reporting flow are designed for Ubuntu

## Main Features
**1. Automatic crash detection**

When an application or system component crashes, apport starts automatically and collects the relevant information.

**2. Crash reports**

Reports are usually stored in /var/crash/ with the extension .crash. They include:
- Program name and version
- Error message and stack trace
- Runtime environment (kernel, glibc, Python, and other versions)
- User and system information (such as CPU architecture and memory state)

**3. Launchpad integration (Ubuntu's bug tracker)**

Users can choose to upload the report to Launchpad for developers to analyze.

## Usage
Apport works automatically by default. It starts and creates a `.crash` file when:

- A program crashes (segmentation fault, core dump, and so on)
- A Python program raises an unhandled exception
- A system service fails (for example, a systemd unit crashes)
- A kernel error happens (needs extra configuration)
These reports are stored in `/var/crash/`.

### File location
```bash
ls /var/crash/
```
You may see files like these:
```
_usr_bin_gnome-shell.1000.crash
_usr_bin_python3.1000.upload
_usr_bin_python3.1000.uploaded
```
### Reading an Apport report
Use apport-unpack to extract a .crash file.
It unpacks the report into several readable files, such as Stacktrace.txt, ProcStatus.txt, and CoreDump.gz.
```bash
mkdir crash_report
apport-unpack /var/crash/_usr_bin_python3.1000.crash crash_report/
```
It produces these files:
| File | Description |
| --- | --- |
| Stacktrace.txt | Stack trace at the time of the error |
| ProcStatus.txt | Memory and execution state of the program |
| CoreDump.gz | The core dump, compressed, if one was produced |
| ExecutablePath | Path of the executable that crashed |
| Signal | The signal that caused the crash (e.g. SIGSEGV) |
| ProblemType | Problem type (e.g. Crash, Bug) |
| Package | Package name and version |

For deeper analysis, decompress CoreDump.gz and analyze it with gdb.
You need to know which executable caused the error (see ExecutablePath).
```
gunzip CoreDump.gz
gdb /path/to/executable CoreDump
```

### Reporting manually
Use `apport-bug` or `apport-cli` to report a bug by hand, for example:
```bash
apport-bug /path/to/crash/file
```

Or for a specific package:
```bash
apport-bug firefox
```
It opens a GUI or CLI where you can review the report and choose whether to upload it.

### Turning Apport off (no automatic reports)
**1. Edit `/etc/default/apport`** and change `enabled=1` to `enabled=0`

**2. Disable the service**

```bash
sudo systemctl disable apport.service
sudo systemctl stop apport.service
```
## More on Core Dumps

> [!NOTE]
>
> - Apport uses its own core dump mechanism and does not fully rely on ulimit -c to decide whether to produce a core dump.
> - When core dumps are routed to Apport (through core_pattern), Apport captures the process memory itself and compresses it into CoreDump.gz, even if ulimit -c is 0.
> - This is Ubuntu's default behavior, so developers can get full diagnostics without users having to configure anything.
> - Check `cat /proc/sys/kernel/core_pattern`. If the output is `|/usr/share/apport/apport %p %s %c %P`, core dumps are sent to Apport instead of being written to disk, and the ulimit -c setting does not stop Apport from capturing memory.

A core dump (also called a core file or memory dump) is a file the system saves when a program hits a serious error (such as a segmentation fault). It contains the program's memory, register state, stack, and so on at that moment.

Developers and system administrators can load it later in a debugger (such as gdb) to reconstruct the execution state and find the cause.
It contains:
1. The program's memory image
2. CPU register state
3. Stack trace
4. Program counter
5. The error signal (such as SIGSEGV)
6. Thread information

### Checking the core dump setting

If the output is `0`, core dumps are disabled, so Apport and other tools cannot collect the memory state when a program crashes.
```bash
ulimit -c
```

### Enable temporarily (current shell only)

```bash
ulimit -c unlimited
```

This allows core dumps of unlimited size, but only for the current terminal session. Use it to test whether a core dump gets produced.

### Enable permanently (recommended)

To keep core dumps enabled after every boot, change a few files:

**1. Edit `/etc/security/limits.conf`**

```bash
sudo nano /etc/security/limits.conf

# Add these two lines at the bottom (for all users):
* soft core unlimited
* hard core unlimited
```

**2. Edit the PAM configuration**

Make sure the PAM module loads the limits settings:

```bash
sudo nano /etc/pam.d/common-session

# Make sure this line exists (add it if not):
session required pam_limits.so
```

**3. Finally: log in again or reboot**

### How to produce a core dump

1. **Allow core dumps:**

```bash
ulimit -c unlimited
```

2. **Run a program that crashes** (e.g. a segmentation fault)

3. **Check whether a core dump was produced:**

```bash
ls core*
```

Or use:

```bash
coredumpctl list
```

### How to analyze a core dump

Use `gdb`:

```bash
gdb /path/to/executable core
```

Useful commands inside gdb:

- `bt`: show the backtrace
- `info locals`: show local variables
- `list`: show source code
- `frame`: switch stack frames

### Location and naming

Controlled by `kernel.core_pattern`:

```bash
cat /proc/sys/kernel/core_pattern
```

Examples:

- `core`: saved in the current directory
- `/var/crash/core.%e.%p.%t`: includes the program name, PID, and timestamp

**Setting where core dumps go (optional)**

You can set the file name and path of core dumps:

```bash
sudo sysctl -w kernel.core_pattern=/var/crash/core.%e.%p.%t
```

To make it permanent, add it to `/etc/sysctl.conf`:

```
kernel.core_pattern=/var/crash/core.%e.%p.%t
```

> [!NOTE]
>
> - Core dumps may contain sensitive data (passwords, keys) and should not be shared casually.
> - Production systems usually disable or limit core dumps.
> - `systemd-coredump` or `Apport` can collect and manage them automatically.
