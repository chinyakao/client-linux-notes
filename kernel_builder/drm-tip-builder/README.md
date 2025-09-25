# Build from Intel drm tip

- Release Page (from ubuntu.com): https://kernel.ubuntu.com/mainline/drm-tip/
- Source Code: https://gitlab.freedesktop.org/drm/tip

## Builder Structure
```
drm-tip-builder
├── config
│   ├── config.20250911
├── output
│   ├── <builded-kernel-files>.deb
├── patch
│   ├── <20250911-drm-patch>.patch
├── src
│   └── tip
└── Dockerfile
```

## Clone git
```
git clone https://gitlab.freedesktop.org/drm/tip.git ./src/tip
```

###### REF
- https://www.intel.com/content/www/us/en/docs/graphics-for-linux/developer-reference/1-0/build-guide.html