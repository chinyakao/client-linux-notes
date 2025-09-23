# Build Linux Kernel from Docker

## Build Steps
1. Enter Builder Environment
    ```
    cd <xxxx-kernel-builder>
    ```
2. Clone Kernel Source
    ```
    git clone <kernel-repo> src/<kernel-repo>
    ```

3. Checkout tag or branch
    ```
    git checkout <tag-or-branch>
    ```

4. Apply Patch
    ```
    git apply ./patch/<file.patch> --verbose
    ```
    or
    ```
    git am ./patch/<file.patch>
    ```

5. Copy Kernel Config to Kernel Source
    ```
    cp ./config/<exist-kernel-config> ./src/<kernel-repo>/.config
    ```

6. Create a `Dockerfile`
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

7. Build Docker image
    ```
    sudo docker build -t <image-name> .
    ```
8. Run Docker Container
    ```
    sudo docker run -it --rm \
        -v "$(pwd)/src/<kernel-repo>:/home/builder/kernel-src" \
        -v "$(pwd)/output:/home/builder/kernel-out" \
        <image-name>
    ```
9. Start to Build Kernel
    ```
    make oldconfig

    make -j $(nproc) deb-pkg LOCALVERSION=<version-name> 2>&1 | tee "../linux-kernel-build_$(date +%Y%m%d_%H%M%S).log" 2>&1

    mkdir -p ../kernel-out/<version-name>
    mv ../linux-* /home/builder/kernel-out/<version-name>
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

## Common Usage
- Check docker image
    ```
    sudo docker images
    ```
- Delete Docker image
    ```
    sudo docker rmi <image-name-or-id>
    ```
- Delete all unused Docker image
    ```
    sudo docker image prune -a
    ```
- Check docker container
    ```
    sudo docker ps -a
    ```
- Stop Docker container
    ```
    sudo docker stop <container-name-or-id>
    ```
- Delete Docker container
    ```
    sudo docker rm <container-name-or-id>
    ```