# Docker Notes

## What is Docker?
Docker is a platform that allows you to **build, run, and manage containers**. Containers are lightweight, portable environments that package your application and its dependencies together.

## Key Concepts

### 1. **Image**
- A snapshot of a container.
- Contains everything needed to run an application (code, libraries, environment).
- Example: `python:3.10`, `nginx`, `ubuntu`.

### 2. **Container**
- A running instance of an image.
- Isolated from the host system.
- You can start, stop, and delete containers.

### 3. **Dockerfile**
- A text file with instructions to build a Docker image.
- Example:
  ```Dockerfile
  FROM node:18
  WORKDIR /app
  COPY . .
  RUN npm install
  CMD ["npm", "start"]
  ```

### 4. **Docker Hub**
- A public registry to share and download Docker images.
- Website: https://hub.docker.com



## Common Docker Commands

| Command | Description |
|--|-|
| `docker --version` | Check Docker version |
| `docker pull <image>` | Download image from Docker Hub |
| `docker build -t <name> .` | Build image from Dockerfile |
| `docker load < <image>.tar` | Loads an image from a .tar file |
| `docker run <image>` | Run a container |
| `docker run -it <image> /bin/bash` | Run a container with interactive bash terminal |
| `docker exec -it <container-id or name> /bin/bash` | Enter a running container with bash |
| `docker ps` | List running containers |
| `docker ps -a` | List all containers (including stopped ones)|
| `docker stop <container-id-or-name>` | Stop a container |
| `docker kill <container-id-or-name>` | Force stop a container |
| `docker rm <container>` | Remove a container |
| `docker container prune` | Remove all stopped containers |
| `docker images` | List downloaded images |
| `docker rmi <image-name-or-id>` | Remove an image |
| `docker image prune -a` | Remove all unused image |


## 🧪 Example: Running a Simple Web Server

```bash
docker run -d -p 8080:80 nginx
```

- `-d`: Run in detached mode
- `-p 8080:80`: Map port 8080 on your machine to port 80 in the container
- `nginx`: Use the nginx image

Visit `http://localhost:8080` to see the web server.



## 📂 Dockerfile Example for Python App

```Dockerfile
FROM python:3.10
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["python", "app.py"]
```

Build and run:
```bash
docker build -t my-python-app .
docker run my-python-app
```



## 🧼 Clean Up Tips

```bash
docker system prune
```
- Removes unused containers, images, and networks.


Would you like this formatted into a downloadable PDF or Markdown file? Or do you want a version in Chinese as well?