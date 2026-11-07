# Kernel Builders

Each folder holds a Dockerfile and kernel config for one kernel source:

| Folder | Source |
|---|---|
| [`mainline-builder/`](mainline-builder/) | Ubuntu mainline kernel builds |
| [`archives-builder/`](archives-builder/) | kernel.org release tarballs |
| [`upstream-builder/`](upstream-builder/) | Torvalds' tree |
| [`drm-tip-builder/`](drm-tip-builder/) | Intel drm-tip |
| [`oem-6.14-builder/`](oem-6.14-builder/) | Ubuntu OEM 6.14 |
| [`oem-6.17-builder/`](oem-6.17-builder/) | Ubuntu OEM 6.17 |

The step-by-step build guide is on the
[website](https://chinyakao.github.io/client-linux-notes/kernel-build/)
([source](../docs/kernel-build/index.md)).
