---
title: "git am 與 git apply"
parent: "編譯 Kernel"
grand_parent: "中文"
nav_order: 1
lang: zh
---

# 套用 Git Patch：`git am` 與 `git apply`

## `git apply`
- **用途**：把 patch 套用到工作目錄。
- **不會建立 commit**。
- **不會保留作者或 commit 資訊**。
- **適用**：手動套用單純的 diff 或 patch。
- **Patch 格式**：Unified diff（由 `git diff` 或 `diff` 產生）。

**範例**：
```bash
git apply my-fix.patch
```

## `git am`
- **用途**：套用 patch 並建立 commit。
- **保留作者、日期與 commit message**。
- **適用**：套用 `git format-patch` 產生的 patch，常見於用 email 傳 patch 的流程。
- **Patch 格式**：Email 格式的 patch（包含 `From:`、`Date:`、`Subject:` 等標頭）。

**範例**：
```bash
git am 0001-fix-bug.patch
```

## Patch 格式種類

### 1. **Email 格式 patch**（給 `git am`）
- 產生方式：`git format-patch`
- 包含：
  - `From:`（作者）
  - `Date:`
  - `Subject:`（commit message）
  - `Signed-off-by:`
  - Diff 內容
- 結尾：`--` 分隔線與 Git 版本資訊

**範例**：
```bash
git format-patch HEAD~1
```

### 2. **Unified diff 格式**（給 `git apply`）
- 產生方式：`git diff`
- 只有檔案變更
- 沒有 commit 資訊

**範例**：
```bash
git diff > changes.patch
```

## 比較表

| 項目 | `git apply` | `git am` |
|------|-------------|----------|
| 建立 commit | ❌ 否 | ✅ 是 |
| 保留作者資訊 | ❌ 否 | ✅ 是 |
| 需要的 patch 格式 | Unified diff | Email 格式 |
| 常見用途 | 手動套 patch | 協作流程 |
| 標頭資訊（From、Date…） | ❌ 忽略 | ✅ 解析並使用 |
