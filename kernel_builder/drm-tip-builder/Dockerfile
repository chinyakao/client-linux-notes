FROM ubuntu:24.04

RUN apt update && apt install -y \
    build-essential \
    libncurses-dev \
    bison \
    flex \
    libssl-dev \
    libelf-dev \
    bc \
    git \
    wget \
    curl \
    ccache \
    libdrm-dev \
    libncurses5-dev \
    libncursesw5-dev \
    libudev-dev \
    libpci-dev \
    libiberty-dev \
    pkg-config \
    vim \
    gawk \
    gcc \
    make \
    dpkg-dev \
    zstd \
    debhelper-compat \
    fakeroot \
    kmod \
    libdw-dev:native \
    python3:native \
    rsync \
    ca-certificates

RUN useradd -ms /bin/bash builder
USER builder

RUN mkdir -p /home/builder/kernel-src /home/builder/kernel-out
WORKDIR /home/builder/kernel-src