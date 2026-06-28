# IDA Pro 9.4 + KasmVNC

Browser-based IDA Pro inside a full XFCE desktop, served via KasmVNC. No local
installation needed — just a browser and a Docker-capable Linux host.

> **Default Credentials**
> | Field | Value |
> |-------|-------|
> | **VNC Username** | `kasm_user` |
> | **VNC Password** | `changeme` (override in `.env` before `make run`) |
>
> ⚠️ Change `VNC_PASSWORD` in `.env` before exposing the container to any network.

---

## What You Get

- **IDA Pro 9.4** installed and ready on `/opt/ida-pro/ida`
- **Full XFCE desktop** in your browser with desktop icons, file manager, etc.
- **Persistent workspace** (`~/workspace`) mounted from the host
- **License mounted at runtime** — never baked into the image
- **One-command build** from macOS (or any dev machine) to a remote Linux builder

## Architecture

```
┌──────────────┐      rsync + SSH      ┌─────────────────────────┐
│ Your machine │  ───────────────────► │ Linux x86_64 Builder    │
│ (macOS etc.) │                     │  - Docker daemon        │
└──────────────┘                     │  - IDA installer        │
                                     └─────────────────────────┘
                                               │
                                               ▼
                                    ┌─────────────────────────┐
                                    │ Docker: ida-vnc:9.4     │
                                    │  ┌──────────────────┐   │
                                    │  │ KasmVNC :6901   │   │
                                    │  │   ▼              │   │
                                    │  │ XFCE Desktop     │   │
                                    │  │   ▼              │   │
                                    │  │ IDA Pro 9.4      │   │
                                    │  └──────────────────┘   │
                                    │  - license (bind mount) │
                                    │  - workspace (bind mount)│
                                    └─────────────────────────┘
                                               │
                                               ▼
                                    https://<builder-ip>:8443
```

## Prerequisites

### On Your Development Machine
- SSH access to a remote Linux x86_64 host (called "Builder" in docs)
- `rsync`, `make`, `ssh` (macOS has them built-in)

### On The Builder (Linux x86_64)
- Docker Engine installed, daemon running
- Your user is in the `docker` group (no sudo required)
- **IDA Pro installer** — the official x86_64 Linux `.run` file (e.g.
  `ida-pro_94_x64linux.run`). Place it on the Builder at:
  ```
  <project-root>/downloads/ida-pro_94_x64linux.run
  ```
  (This path is gitignored — the installer never enters the repo.)
- **IDA license file** (`ida.hexlic`) — optional but recommended. Place it anywhere
  on the Builder and set the path in `.env`.
- Port `8443` (or whatever you set in `HOST_PORT`) accessible from your browser.

## Quick Start

### 1. Clone & Configure

```bash
git clone https://github.com/<your-username>/IDA-VNC.git
cd IDA-VNC
cp .env .env.local   # .env is gitignored — edit it with your real paths
```

Edit `.env` (or `.env.local`) with your Builder details:

```bash
# SSH host alias or IP of your Linux builder
BUILDER_HOST=your-builder

# VNC password (CHANGE THIS)
VNC_PASSWORD=YourStrongPasswordHere

# Absolute path to your IDA installer on the Builder
# The default is already downloads/ida-pro_94_x64linux.run (relative to project root).
# Only change this if you placed the installer elsewhere:
# IDA_INSTALLER=/some/other/path/ida-pro_94_x64linux.run

# Absolute path to your IDA license on the Builder
IDA_HEXLIC_HOST_PATH=/home/you/ida.hexlic

# Absolute path to a persistent workspace directory on the Builder
WORKSPACE_HOST_PATH=/home/you/IDA-workspace
```

### 2. Place The Installer

On the **Builder** (not your Mac), copy the installer into the project:

```bash
# On Builder
mkdir -p ~/projects/IDA-VNC/downloads
cp /path/to/ida-pro_94_x64linux.run ~/projects/IDA-VNC/downloads/
```

> **Why not on the Mac?** The installer is 600+ MB. By placing it directly on the
> Builder, `make build` can use it immediately without a slow rsync.

### 3. Build & Run

From your **Mac** (or wherever you cloned the repo):

```bash
make all    # sync project to Builder + build Docker image
make run    # start the container
```

### 4. Open IDA In Your Browser

```
https://<builder-ip>:8443
```

- Accept the self-signed certificate warning.
- Enter the VNC username: **`kasm_user`**
- Enter the VNC password: whatever you set in `.env` (default: `changeme`)
- You should see the XFCE desktop. Double-click the **IDA Pro 9.4** icon on the
  desktop or open it from the Applications menu.

### 5. Transfer Files To Analyze

**Option A — Pre-mount:** Put files in the Builder's workspace directory
(`$WORKSPACE_HOST_PATH` from `.env`). They appear inside the container at
`~/workspace` automatically.

**Option B — After startup:** Use the KasmVNC sidebar (left edge of the browser)
→ Files → Upload.

**Option C — Docker cp:**
```bash
ssh your-builder
docker cp ./sample.bin ida-vnc:/home/kasm-user/workspace/
```

## File Structure

```
IDA-VNC/
├── .env                    # Environment variables (gitignored — copy and edit)
├── .gitignore
├── Dockerfile              # Image definition (Kasm base + IDA + Qt deps)
├── Makefile                # Mac → Builder automation (sync, build, run, stop)
├── docker-compose.yml      # Alternative: run with Docker Compose
├── README.md               # This file
├── build/
│   ├── custom_startup.sh   # License check + workspace init hook
│   └── ida-pro.desktop     # XFCE desktop icon + menu entry
└── docs/
    └── BUILD.md            # Detailed build guide & troubleshooting
```

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make all` | `sync` + `build` |
| `make sync` | Push project source to Builder via rsync |
| `make build` | Build Docker image on Builder |
| `make run` | Start container on Builder |
| `make stop` | Stop and remove container |
| `make restart` | `stop` + `run` |
| `make shell` | Interactive bash into the running container |
| `make logs` | Tail container logs |
| `make clean` | Remove Docker image from Builder |
| `make prune` | Deep cleanup (image + dangling volumes) |
| `make help` | Show all targets |

## Docker Compose Alternative

If you prefer Compose over the Makefile:

```bash
# On the Builder
cd ~/projects/IDA-VNC
# Make sure .env is present on the Builder, or export variables manually
export HOST_PORT=8443
export VNC_PASSWORD=changeme
export WORKSPACE_HOST_PATH=/home/you/IDA-workspace
export IDA_HEXLIC_HOST_PATH=/home/you/ida.hexlic

docker compose up -d
```

## Troubleshooting

### "ERROR: IDA installer not found"

Make sure the installer exists on the Builder at the path defined by
`IDA_INSTALLER` (default: `downloads/ida-pro_94_x64linux.run` inside the project).

```bash
# On Builder
ls ~/projects/IDA-VNC/downloads/ida-pro_94_x64linux.run
```

### Container starts but browser shows "Connection refused"

- Check the Builder firewall allows `HOST_PORT` (default `8443`).
- Check `docker ps` on the Builder to see if the container is actually running.
- Run `make logs` to see startup errors.

### License not recognized

The `.idapro` directory is pre-created with `kasm-user` ownership. If you mount a
single file, make sure the host path points to a real **file** (not a directory).

```bash
make shell
ls -la ~/.idapro/ida.hexlic
file ~/.idapro/ida.hexlic   # should say "data", not "directory"
```

### Qt / XCB errors when launching IDA

The Dockerfile already installs all required Qt6 XCB libraries (`libxcb-cursor0`,
`libxcb-icccm4`, etc.). If you see similar errors, open an issue with the full
error message — IDA may have added new Qt dependencies.

## Security Notes

- **License file** is never baked into the image. It is mounted read-only at
  runtime.
- **VNC password** defaults to `changeme`. Always override `VNC_PASSWORD` in
  `.env` before exposing the port.
- **Self-signed certificate** — KasmVNC uses a built-in self-signed cert. Accept
  the browser warning, or mount a real certificate pair if you need public access.

## License

This project is a Docker packaging layer. It does **not** include IDA Pro or its
license. You must provide your own legally obtained IDA Pro installer and
license file (`ida.hexlic`).

KasmVNC and the Kasm Core image are trademarks of Kasm Technologies, Inc.
