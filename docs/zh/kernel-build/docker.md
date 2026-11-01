---
title: "Docker"
parent: "編譯 Kernel"
grand_parent: "中文"
nav_order: 4
lang: zh
---

# Docker 筆記

## Docker 是什麼？
Docker 是一個用來**建立、執行、管理 container** 的平台。Container 是輕量、可攜的環境，把應用程式和它的相依套件包在一起。

## 主要概念

### 1. **Image**
- Container 的快照。
- 包含執行應用程式所需的一切（程式碼、函式庫、環境）。
- 例如：`python:3.10`、`nginx`、`ubuntu`。

### 2. **Container**
- Image 執行起來的實例。
- 與主機系統隔離。
- 可以啟動、停止、刪除。

### 3. **Dockerfile**
- 描述如何建立 Docker image 的文字檔。
- 範例：
  ```Dockerfile
  FROM node:18
  WORKDIR /app
  COPY . .
  RUN npm install
  CMD ["npm", "start"]
  ```

### 4. **Docker Hub**
- 公開的 image 倉庫，可以分享與下載 image。
- 網站：https://hub.docker.com


## 常用指令

| 指令 | 說明 |
|--|-|
| `docker --version` | 查看 Docker 版本 |
| `docker pull <image>` | 從 Docker Hub 下載 image |
| `docker build -t <name> .` | 用 Dockerfile 建立 image |
| `docker load < <image>.tar` | 從 .tar 檔載入 image |
| `docker run <image>` | 執行 container |
| `docker run -it <image> /bin/bash` | 執行 container 並開互動式 bash |
| `docker run -it --user root <image-name> /bin/bash` | 以 root 身分執行 container |
| `docker exec -it <container-id or name> /bin/bash` | 進入執行中的 container |
| `docker ps` | 列出執行中的 container |
| `docker ps -a` | 列出所有 container（包含已停止的） |
| `docker stop <container-id-or-name>` | 停止 container |
| `docker kill <container-id-or-name>` | 強制停止 container |
| `docker rm <container>` | 刪除 container |
| `docker container prune` | 刪除所有已停止的 container |
| `docker images` | 列出已下載的 image |
| `docker rmi <image-name-or-id>` | 刪除 image |
| `docker image prune -a` | 刪除所有沒在用的 image |


## 範例：執行一個簡單的 web server

```bash
docker run -d -p 8080:80 nginx
```

- `-d`：在背景執行
- `-p 8080:80`：把本機的 8080 port 對應到 container 的 80 port
- `nginx`：使用 nginx image

打開 `http://localhost:8080` 就能看到 web server。



## Python 應用程式的 Dockerfile 範例

```Dockerfile
FROM python:3.10
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["python", "app.py"]
```

建立並執行：
```bash
docker build -t my-python-app .
docker run my-python-app
```



## 清理

```bash
docker system prune
```
- 刪除沒在用的 container、image 和 network。
