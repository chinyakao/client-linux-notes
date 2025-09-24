FROM ubuntu:24.04

RUN apt update && apt install -y \
    bc \
    bison \
    build-essential \
    ca-certificates \
    ccache \
    curl \
    debhelper-compat \
    dpkg-dev \
    fakeroot \
    flex \
    gawk \
    gcc \
    git \
    kmod \
    libdrm-dev \
    libdw-dev:native \
    libelf-dev \
    libiberty-dev \
    libncurses-dev \
    libncurses5-dev \
    libncursesw5-dev \
    libpci-dev \
    libssl-dev \
    libudev-dev \
    make \
    pkg-config \
    python3:native \
    rsync \
    vim \
    wget \
    zstd

RUN useradd -ms /bin/bash builder
USER builder

RUN mkdir -p /home/builder/kernel-src /home/builder/kernel-out
WORKDIR /home/builder/kernel-src