# Build from Ubuntu Kernel Mainline

- Release Page (from ubuntu.com): https://kernel.ubuntu.com/mainline/
- Source Code: https://git.launchpad.net/~ubuntu-kernel-test/ubuntu/+source/linux/+git/mainline-crack

## Builder Structure
```
mainline-builder
├── config
│   ├── config-6.17.0-061700rc7-generic
├── output
│   ├── <builded-kernel-files>.deb
├── patch
│   ├── 
├── src
│   └── mainline-crack
└── Dockerfile
```

## Clone and Switch git branch/tag

```
git clone git://git.launchpad.net/~ubuntu-kernel-test/ubuntu/+source/linux/+git/mainline-crack
git tag -l | grep -i <target-version>
git checkout <tag-or-branch e.g., tags/cod/tip/drm-tip/2025-09-10 or cod/mainline/v6.17-rc7>
```
