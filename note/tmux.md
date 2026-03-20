Below is a **clean, pure‑text English note** summarizing **tmux usage for server-side long‑running tasks** (e.g. kernel build).  
It **does NOT include PowerShell or Windows content**, and is suitable for a personal README or wiki.

***

# tmux Notes (Server-Side Usage)

## 1. What is tmux?

tmux is a **terminal multiplexer that runs on the server**.

It allows terminal sessions to **persist independently of SSH connections**.  
If your SSH disconnects or your computer shuts down, tmux sessions continue running.

Typical use cases:

*   Long-running tasks (kernel build, Docker build, training jobs)
*   Unstable network / frequent SSH disconnects
*   Re-attaching to the exact same terminal state later

***

## 2. Standard Workflow (Recommended)

### Step 1: SSH into the server

```bash
ssh user@server
```

### Step 2: Create a tmux session

```bash
tmux new -s kernel
```

Notes:

*   `kernel` is just a **session name**
*   You can name it anything (`build`, `work`, `debug`, etc.)
*   Naming helps identify sessions later

### Step 3: Run your work inside tmux

Example:

```bash
docker run -it ubuntu /bin/bash
make -j$(nproc)
```

### Step 4: Detach from tmux (safe exit)

```text
Ctrl + B, then D
```

Result:

*   tmux session keeps running
*   Docker and build process keep running
*   SSH can disconnect safely

### Step 5: Reattach later

```bash
ssh user@server
tmux attach -t kernel
```

You return to the exact same terminal state.

***

## 3. Core tmux Concepts

*   **Session**: A persistent workspace (what you usually care about)
*   **Window**: Like a tab inside a session
*   **Pane**: Split view inside a window

For long-running builds, you mainly interact with **sessions**.

***

## 4. Common tmux Commands (Outside tmux)

List all sessions:

```bash
tmux ls
```

Create a new session:

```bash
tmux new -s <name>
```

Attach to an existing session:

```bash
tmux attach -t <name>
```

Kill a session (terminates all processes inside):

```bash
tmux kill-session -t <name>
```

***

## 5. Common tmux Key Bindings (Inside tmux)

tmux uses a **prefix key**:

```text
Ctrl + B
```

Common actions:

Detach from session (recommended):

```text
Ctrl + B, then D
```

Enter command mode:

```text
Ctrl + B, then :
```

Kill the current session (from command mode):

```text
:kill-session
```

***

## 6. How to Exit tmux (Important)

### Case 1: You want the task to KEEP running

✅ Use **detach**

```text
Ctrl + B, then D
```

Do NOT exit the shell.

***

### Case 2: You want to STOP everything

❌ This will terminate all running processes:

Inside tmux:

```bash
exit
```

or

```text
Ctrl + D
```

Or from outside tmux:

```bash
tmux kill-session -t <name>
```

***

## 7. Best Practices

*   Always start long-running tasks inside tmux
*   Detach instead of exiting when leaving
*   Use meaningful session names
*   Run tmux on the **server**, not inside Docker containers
*   Do not rely on raw SSH sessions for long builds

***

## 8. One‑Line Summary

tmux allows server-side work to survive SSH disconnects.  
If a task takes a long time, start tmux first.

***

If you want, I can also provide:

*   tmux window/pane cheat sheet
*   tmux + Docker best practices
*   A minimal “daily tmux workflow” template
