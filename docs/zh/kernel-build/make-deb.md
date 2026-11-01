---
title: "deb-pkg 與 bindeb-pkg"
parent: "編譯 Kernel"
grand_parent: "中文"
nav_order: 2
lang: zh
---

# 編譯 Linux Kernel：`make deb-pkg` 與 `make bindeb-pkg`

- 需要同時產生 binary 和 source 套件時（特別是要發佈或封存），用 `make deb-pkg`。
- 只需要 binary 時用 `make bindeb-pkg`，比較精簡，適合自動化流程或部署。

## **1. 指令概覽**

| 指令 | 說明 |
|------|------|
| `make deb-pkg` | 同時產生 binary 與 source 的 Debian 套件。 |
| `make bindeb-pkg` | 只產生 binary Debian 套件，並用 `fakeroot` 處理檔案擁有者。 |


## **2. 主要差異**

| 項目 | `make deb-pkg` | `make bindeb-pkg` |
|------|----------------|-------------------|
| 套件類型 | Binary + Source | 只有 Binary |
| 使用 `fakeroot` | ❌ 否 | ✅ 是 |
| 檔案擁有者 | 由使用者擁有 | 看起來由 root 擁有（標準做法） |
| 產生的檔案 | `.deb`、`.buildinfo`、`.changes`、`.dsc`、`.orig.tar.gz`、`.debian.tar.gz` | `.deb`、`.buildinfo`、`.changes` |
| 用途 | 開發、測試、發佈原始碼 | CI/CD、部署 |


## `make deb-pkg` 多出來的檔案

用 `make deb-pkg` 時，還會產生以下 **source 套件檔案**：

### **1. `.orig.tar.gz`**
- 上游原始碼。
- 保留未修改的原始碼，方便重現與追蹤上游。

### **2. `.debian.tar.gz`**
- Debian 專用的打包檔案與 patch。
- 包含 `debian/` 目錄，裡面有 `control`、`rules`、`changelog` 等資訊。

### **3. `.dsc`（Debian Source Control）**
- 描述 source 套件的資訊檔。
- 列出 checksum、版本、維護者，以及 `.orig.tar.gz` 和 `.debian.tar.gz` 的參照。


### **這些檔案的用途**

這三個檔案合起來就是一個 **Debian source 套件**，可以用來：
- 在其他系統上重新編出 `.deb`。
- 提交到 Debian 或其他 apt 套件庫。
- 確保編譯過程可重現、可追蹤。
