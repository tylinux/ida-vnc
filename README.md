# IDA Pro + KasmVNC

Run **IDA Pro** inside a Docker container with a full **XFCE desktop**,
accessible entirely from your web browser via **KasmVNC**.

No local GUI installation, no X11 forwarding, no VNC client — just a browser.

> **Default Credentials**
> | Field | Value |
> |-------|-------|
> | **VNC Username** | `kasm_user` |
> | **VNC Password** | `changeme` (change before exposing to any network) |
>
> ⚠️ **Security:** Always override `VNC_PASSWORD` via environment variable before
> running the container on a network you do not fully control.

---

## What You Get

- **IDA Pro** installed and ready on `/opt/ida-pro/ida`
- **Full XFCE desktop** in your browser with desktop icons, file manager, terminal
- **Persistent workspace** (`~/workspace`) mounted from the host
- **Runtime license mount** — your `ida.hexlic` is never baked into the image
- **One-command build and run** on any Linux x86_64 machine with Docker

## Architecture

```
┌─────────────────────────────────┐
│  Your Linux x86_64 host         │
│  - Docker daemon                │
│  - IDA installer (.run)         │
│  - ida.hexlic (optional)        │
└─────────────────────────────────┘
              │ docker build / run
              ▼
┌─────────────────────────────────┐
│  Docker: ida-vnc:9.4          │
│  ┌──────────────────────────┐   │
│  │ KasmVNC (:6901)          │   │
│  │   ▼                      │   │
│  │ XFCE Desktop             │   │
│  │   ▼                      │   │
│  │ IDA Pro 9.4              │   │
│  └──────────────────────────┘   │
│  - license (bind mount, ro)       │
│  - workspace (bind mount)         │
└─────────────────────────────────┘
              │
              ▼
        https://localhost:8443
```

## Prerequisites

- **Linux x86_64** host (or any host that can run x86_64 Docker containers)
- **Docker Engine** installed and running
- **IDA Pro installer** — the official x86_64 Linux `.run` file (e.g.
  `ida-pro_94_x64linux.run`)
- **IDA license** (`ida.hexlic`) — optional but recommended
- A modern web browser

> **Note for macOS / ARM users:** If you develop on a non-x86_64 machine, you can
> still build and run this image on a remote Linux x86_64 builder via SSH. See
> [docs/BUILD.md](docs/BUILD.md) for advanced remote-build instructions.

## Quick Start

### 1. Clone & Prepare

```bash
git clone https://github.com/<your-username>/ida-vnc.git
cd ida-vnc
```

Place your IDA Pro installer in the `downloads/` directory (gitignored):

```bash
cp /path/to/ida-pro_94_x64linux.run downloads/
```

> **Why not commit the installer?** The `.run` file is ~600 MB and is licensed
> software. `downloads/*.run` is already gitignored so it never enters the repo.

### 2. Build The Image

```bash
docker build -t ida-vnc:9.4 .
```

### 3. Run The Container

```bash
mkdir -p ~/IDA-workspace

docker run -d \
  --name ida-vnc \
  -p 8443:6901 \
  -e VNC_PW=changeme \
  -v ~/IDA-workspace:/home/kasm-user/workspace \
  -v ~/ida.hexlic:/home/kasm-user/.idapro/ida.hexlic:ro \
  ida-vnc:9.4
```

> **No license file yet?** Omit the `-v ~/ida.hexlic:...` line. IDA will start
> in evaluation mode and the container will print a friendly reminder.

### 4. Open In Your Browser

```
https://localhost:8443
```

- Accept the self-signed certificate warning.
- Enter the VNC username: **`kasm_user`**
- Enter the VNC password: `changeme` (or whatever you set via `-e VNC_PW=`)
- You should see the XFCE desktop. Double-click the **IDA Pro 9.4** icon on the
  desktop, or open it from the Applications menu.

### 5. Stop & Cleanup

```bash
# Stop and remove the container
docker stop ida-vnc && docker rm ida-vnc

# Remove the image
docker rmi ida-vnc:9.4

# Deep cleanup
docker system prune -f
```

## Using Docker Compose

If you prefer Compose over raw `docker` commands:

```bash
# Copy the example env and edit
export HOST_PORT=8443
export VNC_PASSWORD=changeme
export WORKSPACE_HOST_PATH=$HOME/IDA-workspace
export IDA_HEXLIC_HOST_PATH=$HOME/ida.hexlic

docker compose up -d
```

Or create a `.env` file with those variables and simply run:

```bash
docker compose up -d
```

## Using The Makefile (Optional)

A `Makefile` is provided as a convenience wrapper around `docker` commands.

```bash
make build    # docker build -t ida-vnc:9.4 .
make run      # docker run with standard mounts
make stop     # docker stop + rm
make restart  # stop + run
make shell    # docker exec -it ida-vnc bash
make logs     # docker logs -f ida-vnc
make clean    # docker rmi ida-vnc:9.4
make prune    # deep cleanup
make help     # show all targets
```

You can override defaults via environment variables or a `.env` file:

```bash
export VNC_PASSWORD=MySecurePassword
export HOST_PORT=8443
export IDA_HEXLIC_HOST_PATH=$HOME/ida.hexlic
export WORKSPACE_HOST_PATH=$HOME/IDA-workspace
make run
```

## File Structure

```
ida-vnc/
├── .env.example              # Environment template (copy to .env)
├── .gitignore
├── Dockerfile                # Image definition (Kasm base + IDA + Qt deps)
├── Makefile                  # Convenience wrapper for local docker commands
├── docker-compose.yml        # Alternative: run with Docker Compose
├── README.md                 # This file
├── build/
│   ├── custom_startup.sh     # License check + workspace init hook
│   └── ida-pro.desktop       # XFCE desktop icon + menu entry
└── docs/
    └── BUILD.md              # Detailed build guide & troubleshooting
```

## Transferring Files To Analyze

**Option A — Pre-mount:** Place files in the directory you mount as
`/home/kasm-user/workspace` (e.g. `~/IDA-workspace`). They appear inside the
container automatically.

**Option B — After startup:** Use the KasmVNC sidebar (left edge of browser)
→ **Files** → **Upload**.

**Option C — Docker cp:**
```bash
docker cp ./sample.bin ida-vnc:/home/kasm-user/workspace/
```

## Troubleshooting

### Container exits immediately

Check the logs:
```bash
docker logs ida-vnc
```

Common causes:
- **Port conflict:** `8443` is already in use. Change the host port:
  `-p 8444:6901` and access `https://localhost:8444`.
- **License mount is a directory:** If `~/ida.hexlic` does not exist on the host,
  Docker creates it as a directory. Delete the directory and ensure the file exists.

### IDA fails to start with Qt / XCB errors

The Dockerfile already installs all required Qt6 XCB libraries (`libxcb-cursor0`,
`libxcb-icccm4`, etc.). If you see similar errors, open an issue with the full
error message — IDA may have added new Qt dependencies.

### Browser shows "Connection refused"

- Container is not running: `docker ps`
- Wrong port: verify `docker ps` shows the correct host port mapping
- Firewall blocking the port

### License not recognized

Verify the mount is a file, not a directory:
```bash
docker exec ida-vnc bash -c "file ~/.idapro/ida.hexlic"
# Should say: data
# If it says: directory → delete the host directory and put a real file there
```

## Security Notes

- **License file** is never baked into the image. It is mounted read-only at
  runtime.
- **VNC password** defaults to `changeme`. Always override it via `-e VNC_PW=`
  or `VNC_PASSWORD` in `.env` before exposing the port.
- **Self-signed certificate:** KasmVNC uses a built-in self-signed certificate.
  Accept the browser warning for local use, or mount a real certificate pair if
  you need public access.

## License

This project is a Docker packaging layer. It does **not** include IDA Pro or its
license. You must provide your own legally obtained IDA Pro installer and
license file (`ida.hexlic`).

KasmVNC and the Kasm Core image are trademarks of Kasm Technologies, Inc.
