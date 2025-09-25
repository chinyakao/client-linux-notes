# Build Linux Kernel from Docker

## Setup
1. Create and Enter the builder directory with below structure
    ```
    xxxx-kernel-builder
    ├── config
    │   ├── <exist-kernel-config>.config
    ├── output
    │   ├── <builded-kernel-files>.deb
    ├── patch
    │   ├── *.patch
    └── src
        └── <kernel-source-code>
    ```

2. Clone or Download Kernel Source
    ```
    git clone <kernel-repo> src/<kernel-repo>
    git checkout <tag-or-branch> # if needed
    ```
    or
    ```
    wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.0.10.tar.xz
    tar xvf linux-6.0.10.tar.xz
    ```

3. Apply Patch (If needed)
    ```
    git apply ./patch/<file.patch> --verbose
    ```
    or
    ```
    git am ./patch/<file.patch>
    ```
    [Note: `git am` vs `git apply`](../note/git_patch.md)

4. Copy Kernel Config to Kernel Source
    ```
    cp ./config/<exist-kernel-config> ./src/<kernel-repo>/.config
    ```
    or copy from system
    ```
    cp /boot/config-`uname -r` ./src/<kernel-repo>/.config
    ```
    > Note: Remove `cert key` in conifg file.
    >   
    >   ```
    >   # (Original)
    >   CONFIG_SYSTEM_TRUSTED_KEYS="debian/canonical-certs.pem"
    >   CONFIG_SYSTEM_REVOCATION_KEYS="debian/canonical-revoked-certs.pem"
    >   ```
    >   ```
    >   # (Revised)
    >   CONFIG_SYSTEM_TRUSTED_KEYS=""
    >   CONFIG_SYSTEM_REVOCATION_KEYS=""
    >   ```

## Build Steps
1. Enter Builder Environment
    ```
    cd <xxxx-kernel-builder>
    ```

2. Create a `Dockerfile`
    ```
    FROM ubuntu:24.04

    # Install dependencies
    RUN apt update && apt install -y \
        build-essential \
        <dependencies>

    # Add a non-root user
    RUN useradd -ms /bin/bash builder
    USER builder

    # Set working directory
    RUN mkdir -p /home/builder/kernel-src /home/builder/kernel-out
    WORKDIR /home/builder/kernel-src
    ``` 

3. Build Docker image
    ```
    sudo docker build -t <image-name> .
    ```

4. Run Docker Container
    ```
    sudo docker run -it --rm \
        -v "$(pwd)/src/<kernel-repo>:/home/builder/kernel-src" \
        -v "$(pwd)/output:/home/builder/kernel-out" \
        <image-name>
    ```
    [Note: Docker Common Commands](../note/docker.md)

5. Make config from copyed config file
    ```
    make oldconfig
    ```

6. Build Kernel with log output
    ```
    make -j $(nproc) bindeb-pkg LOCALVERSION=<version-name> 2>&1 | tee "../linux-kernel-build_$(date +%Y%m%d_%H%M%S).log" 2>&1
    ```
    [Note: `make deb-pkg` vs `make bindeb-pkg`](../note/make_deb.md)

7. Move Built Files to ouput directory
    ``` 
    mkdir -p ../kernel-out/<version-name>
    mv ../linux-* /home/builder/kernel-out/<version-name>
    ```

8. Exit Docker Container
    ```
    exit
    ```

## Install Custom-built kernel
- Required:
    - `linux-image-6.17.0-rc6-custom-built_*.deb`
    
        → Installs the kernel image (includes vmlinuz)
    - `linux-headers-6.17.0-rc6-custom-built_*.deb`

        → Installs kernel headers, needed for compiling DKMS modules or external drivers
- Optional:
    - `linux-libc-dev_*.deb`
    
        → Useful if you're compiling programs that depend on kernel libc headers (e.g., glibc)
    - `linux-image-6.17.0-rc6-custom-built-dbg_*.deb`
    
        → Installs debug symbols for kernel debugging (e.g., with GDB)
- Example:
    ```
    sudo dpkg -i linux-image-6.17.0-rc6-custom-built_*.deb
    sudo dpkg -i linux-headers-6.17.0-rc6-custom-built_*.deb
    ```
    If there are dependency issues, you can fix them with:
    ```
    sudo apt --fix-broken install
    ```

## Check & Boot into Custom-built Kernel
reboot and keep pressing f4 to get into "GRUB menu", then select custom-built kernel in "Advance boot option"

## Troubleshooting
- Grep the error from the build log
    - `grep -i "error" ./output/linux-kernel-build_*.log`
    - `grep -i "failed" ./output/linux-kernel-build_*.log`
    - `grep -i "not found" ./output/linux-kernel-build_*.log`
    - `grep -i "Unmet build dependencies" ./output/linux-kernel-build_*.log`

- Solve the error: `No rule to make target ‘debian/canonical-certs.pem‘, needed by ‘certs/x509_certificate_list‘`
https://unix.stackexchange.com/questions/293642/attempting-to-compile-kernel-yields-a-certification-error/649484#649484
- Solve the error: `/bin/sh: 1:zstd: not found`
https://forum.openwrt.org/t/ubuntu-20-04-compile-zstd-error/66619

###### REF
- https://www.kernel.org/
- https://docs.kernel.org/
- https://kernelnewbies.org/KernelBuild
- https://wiki.ubuntu.com/KernelTeam/GitKernelBuild
