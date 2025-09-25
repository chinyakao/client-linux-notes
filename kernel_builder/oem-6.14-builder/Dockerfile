FROM ubuntu:24.04

RUN apt update && apt install -y \
    bc \
    bison \
    debhelper-compat \
    dpkg-dev \
    flex \
    gawk \
    gcc \
    kmod \
    libdw-dev \
    libelf-dev \
    libssl-dev \
    make \
    python3 \
    rsync \
    zstd

RUN useradd -ms /bin/bash builder
USER builder

RUN mkdir -p /home/builder/kernel-src /home/builder/kernel-out
WORKDIR /home/builder/kernel-src