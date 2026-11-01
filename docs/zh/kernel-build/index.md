---
title: "編譯 Kernel"
parent: "中文"
nav_order: 1
has_children: true
lang: zh
---

# 用 Docker 編譯 Linux Kernel

## 準備
1. 建立 builder 資料夾並進入，結構如下
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

2. Clone 或下載 kernel 原始碼
    ```
    git clone <kernel-repo> src/<kernel-repo>
    git checkout <tag-or-branch> # 視需要
    ```
    或
    ```
    wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.0.10.tar.xz
    tar xvf linux-6.0.10.tar.xz
    ```

3. 套用 patch（視需要）
    ```
    git apply ./patch/<file.patch> --verbose
    ```
    或
    ```
    git am ./patch/<file.patch>
    ```
    [筆記：`git am` 與 `git apply` 的差別](git-patch.md)

4. 把 kernel config 複製到原始碼目錄
    ```
    cp ./config/<exist-kernel-config> ./src/<kernel-repo>/.config
    ```
    或從目前系統複製
    ```
    cp /boot/config-`uname -r` ./src/<kernel-repo>/.config
    ```
    > 注意：要移除 config 裡的憑證 key 設定。
    >
    >   ```
    >   # （原本）
    >   CONFIG_SYSTEM_TRUSTED_KEYS="debian/canonical-certs.pem"
    >   CONFIG_SYSTEM_REVOCATION_KEYS="debian/canonical-revoked-certs.pem"
    >   ```
    >   ```
    >   # （修改後）
    >   CONFIG_SYSTEM_TRUSTED_KEYS=""
    >   CONFIG_SYSTEM_REVOCATION_KEYS=""
    >   ```

## 編譯步驟
0. （選用）開一個 tmux session，讓終端機不受 SSH 斷線影響
    ```
    tmux new -s <session-name>
    ```
1. 進入 builder 環境
    ```
    cd <xxxx-kernel-builder>
    ```

2. 建立 `Dockerfile`
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

3. 建立 Docker image
    ```
    sudo docker build -t <image-name> .
    ```

4. 執行 Docker container
    ```
    sudo docker run -it --rm \
        -v "$(pwd)/src/<kernel-repo>:/home/builder/kernel-src" \
        -v "$(pwd)/output:/home/builder/kernel-out" \
        <image-name>
    ```
    [筆記：Docker 常用指令](docker.md)

5. 從複製來的 config 產生設定
    ```
    make oldconfig
    ```

6. 編譯 kernel 並輸出 log
    ```
    make -j $(nproc) bindeb-pkg LOCALVERSION=<version-name> 2>&1 | tee "../linux-kernel-build_$(date +%Y%m%d_%H%M%S).log" 2>&1
    ```
    [筆記：`make deb-pkg` 與 `make bindeb-pkg` 的差別](make-deb.md)

7. 把編好的檔案移到 output 目錄
    ```
    mkdir -p ../kernel-out/<version-name>
    mv ../linux-* /home/builder/kernel-out/<version-name>
    ```

8. 離開 Docker container
    ```
    exit
    ```

## 安裝自己編的 kernel
- 必要：
    - `linux-image-6.17.0-rc6-custom-built_*.deb`

        → 安裝 kernel image（包含 vmlinuz）
    - `linux-headers-6.17.0-rc6-custom-built_*.deb`

        → 安裝 kernel headers，編譯 DKMS 模組或外部 driver 時需要
- 選用：
    - `linux-libc-dev_*.deb`

        → 編譯依賴 kernel libc headers 的程式時有用（例如 glibc）
    - `linux-image-6.17.0-rc6-custom-built-dbg_*.deb`

        → 安裝 debug symbols，用於 kernel 除錯（例如 GDB）
- 範例：
    ```
    sudo dpkg -i linux-image-6.17.0-rc6-custom-built_*.deb
    sudo dpkg -i linux-headers-6.17.0-rc6-custom-built_*.deb
    ```
    如果有相依性問題，可以這樣修：
    ```
    sudo apt --fix-broken install
    ```

## 確認並開機進入自己編的 kernel
重開機時一直按 F4 進入 GRUB 選單，在「Advanced boot options」選擇自己編的 kernel。

## 疑難排解
- 從 build log 找錯誤
    - `grep -i "error" ./output/linux-kernel-build_*.log`
    - `grep -i "failed" ./output/linux-kernel-build_*.log`
    - `grep -i "not found" ./output/linux-kernel-build_*.log`
    - `grep -i "Unmet build dependencies" ./output/linux-kernel-build_*.log`

- 解決錯誤：`No rule to make target ‘debian/canonical-certs.pem‘, needed by ‘certs/x509_certificate_list‘`
https://unix.stackexchange.com/questions/293642/attempting-to-compile-kernel-yields-a-certification-error/649484#649484
- 解決錯誤：`/bin/sh: 1:zstd: not found`
https://forum.openwrt.org/t/ubuntu-20-04-compile-zstd-error/66619

###### 參考
- https://www.kernel.org/
- https://docs.kernel.org/
- https://kernelnewbies.org/KernelBuild
- https://wiki.ubuntu.com/KernelTeam/GitKernelBuild
