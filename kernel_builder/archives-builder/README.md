# Build from The Linux Kernel Archives
- Release Page: https://www.kernel.org/
- Source Code: https://cdn.kernel.org/pub/linux/kernel/

## Builder Structure
```
mainline-builder
├── config
│   ├── config-6.16.8-061608-generic
├── output
│   ├── <builded-kernel-files>.deb
├── patch
│   ├── 
├── src
│   ├── linux-6.16.8.tar.xz
│   └── linux-6.16.8
└── Dockerfile
```

## Download Source Code
```
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.0.10.tar.xz
tar xvf linux-6.16.8.tar.xz
cd linux-6.16.8
```

###### REF
- https://www.youtube.com/watch?v=1gEFYoGUFxM