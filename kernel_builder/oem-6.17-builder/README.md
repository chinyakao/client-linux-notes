# Build from Ubuntu OEM-6.17 Kernel

- Release Page: https://code.launchpad.net/ubuntu/+source/linux-oem-6.14
- Source Code: https://git.launchpad.net/ubuntu/+source/linux-oem-6.14
- Source Code: Gitea

## Builder Structure

```
oem-6.17-builder
├── config
│   ├── config-6.17.0-1012-oem
├── output
│   ├── <builded-kernel-files>.deb
├── patch
│   ├── 
├── src
│   └── oem-6.17-builder
└── Dockerfile
```

## Clone and Switch git branch/tag

```
git clone https://git.launchpad.net/ubuntu/+source/linux-oem-6.17 ./src/linux-oem-6.17
```