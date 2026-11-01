---
title: "tmux"
parent: "編譯 Kernel"
grand_parent: "中文"
nav_order: 5
lang: zh
---

# tmux 筆記（伺服器端使用）

## 1. tmux 是什麼？

tmux 是**在伺服器上執行的終端機多工器**。

它讓終端機 session **不受 SSH 連線影響持續存在**。
即使 SSH 斷線或你的電腦關機，tmux session 仍會繼續執行。

常見用途：

*   長時間的工作（編 kernel、Docker build、訓練模型）
*   網路不穩、SSH 常斷線
*   之後要回到完全相同的終端機狀態

***

## 2. 標準流程（建議）

### 步驟 1：SSH 登入伺服器

```bash
ssh user@server
```

### 步驟 2：建立 tmux session

```bash
tmux new -s kernel
```

說明：

*   `kernel` 只是 **session 名稱**
*   可以取任何名字（`build`、`work`、`debug` 等）
*   有名字比較容易之後辨認

### 步驟 3：在 tmux 裡執行工作

範例：

```bash
docker run -it ubuntu /bin/bash
make -j$(nproc)
```

### 步驟 4：離開 tmux（安全離開）

```text
Ctrl + B，再按 D
```

結果：

*   tmux session 持續執行
*   Docker 和編譯繼續跑
*   可以放心中斷 SSH

### 步驟 5：之後重新接回

```bash
ssh user@server
tmux attach -t kernel
```

會回到完全相同的終端機狀態。

***

## 3. tmux 核心概念

*   **Session**：持續存在的工作空間（通常最在意的就是這個）
*   **Window**：session 裡的分頁
*   **Pane**：window 裡的分割畫面

跑長時間編譯時，主要操作的是 **session**。

***

## 4. 常用 tmux 指令（在 tmux 外）

列出所有 session：

```bash
tmux ls
```

建立新的 session：

```bash
tmux new -s <name>
```

接回現有的 session：

```bash
tmux attach -t <name>
```

結束 session（會終止裡面所有程式）：

```bash
tmux kill-session -t <name>
```

***

## 5. 常用快捷鍵（在 tmux 內）

tmux 使用 **prefix 鍵**：

```text
Ctrl + B
```

常用操作：

離開 session（建議）：

```text
Ctrl + B，再按 D
```

進入指令模式：

```text
Ctrl + B，再按 :
```

結束目前的 session（在指令模式）：

```text
:kill-session
```

***

## 6. 如何離開 tmux（重要）

### 情況 1：要讓工作繼續跑

✅ 用 **detach**

```text
Ctrl + B，再按 D
```

不要結束 shell。

***

### 情況 2：要停止所有東西

❌ 這會終止所有執行中的程式：

在 tmux 內：

```bash
exit
```

或

```text
Ctrl + D
```

或在 tmux 外：

```bash
tmux kill-session -t <name>
```

***

## 7. 最佳做法

*   長時間的工作一律在 tmux 裡跑
*   離開時用 detach，不要 exit
*   session 取有意義的名字
*   tmux 跑在**伺服器**上，不要跑在 Docker container 裡
*   長時間編譯不要只靠單純的 SSH session

***

## 8. 一句話總結

tmux 讓伺服器上的工作不受 SSH 斷線影響。
要跑很久的工作，先開 tmux。
