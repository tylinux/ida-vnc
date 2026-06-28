# Build & Deployment Guide

## Prerequisites

- **Linux x86_64** host (or any Docker host capable of running x86_64 containers)
- **Docker Engine** installed and running
- **IDA Pro installer** — the official x86_64 Linux `.run` file (e.g.
  `ida-pro_94_x64linux.run`)
- **IDA license** (`ida.hexlic`) — optional but recommended

## Quick Start (Local Build)

### 1. Prepare The Installer

Place the installer in the project directory:

```bash
cd ida-vnc
mkdir -p downloads
cp /path/to/ida-pro_94_x64linux.run downloads/
```

> `downloads/*.run` is gitignored — the installer never enters the repository.

### 2. Build The Image

```bash
docker build -t ida-vnc:9.4 .
```

Or with the Makefile:

```bash
make build
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

Or with the Makefile:

```bash
make run
```

### 4. Access IDA Pro

Open your browser:

```
https://localhost:8443
```

- Accept the self-signed certificate warning.
- Enter the VNC username: **`kasm_user`**
- Enter the VNC password: `changeme` (or whatever you set via `-e VNC_PW=`)
- You should see the XFCE desktop. Click the **IDA Pro 9.4** icon on the desktop
  or open it from the Applications menu.

### 5. Stop & Cleanup

```bash
# Stop and remove container
docker stop ida-vnc && docker rm ida-vnc

# Remove image
docker rmi ida-vnc:9.4

# Deep cleanup
docker system prune -f
```

Or with the Makefile:

```bash
make stop
make clean
make prune
```

## Using Docker Compose

```bash
# Set variables inline or via .env file
export HOST_PORT=8443
export VNC_PASSWORD=changeme
export WORKSPACE_HOST_PATH=$HOME/IDA-workspace
export IDA_HEXLIC_HOST_PATH=$HOME/ida.hexlic

docker compose up -d
```

## Using The Makefile (Optional)

| Target | Description |
|--------|-------------|
| `make build` | Build Docker image locally |
| `make run` | Start container locally |
| `make stop` | Stop and remove container |
| `make restart` | `stop` + `run` |
| `make shell` | Bash into running container |
| `make logs` | Tail container logs |
| `make clean` | Remove Docker image |
| `make prune` | Deep cleanup (image + volumes) |
| `make help` | Show all targets |

Override defaults via `.env` or environment variables:

```bash
export VNC_PASSWORD=MySecurePassword
export HOST_PORT=8443
export IDA_HEXLIC_HOST_PATH=$HOME/ida.hexlic
export WORKSPACE_HOST_PATH=$HOME/IDA-workspace
export IDA_INSTALLER=downloads/ida-pro_94_x64linux.run
make run
```

## Advanced: Full Config Persistence

By default, only the `workspace` and `ida.hexlic` are persistent. If you want IDA
plugins, settings, and history to survive container restarts, mount the entire
`.idapro` directory (writable) instead of a single file:

```bash
# Create a directory on the host that contains your license
mkdir -p ~/IDA-config
cp ~/ida.hexlic ~/IDA-config/ida.hexlic

# Mount the directory (remove :ro to allow writes)
docker run -d \
  ... \
  -v ~/IDA-config:/home/kasm-user/.idapro \
  ida-vnc:9.4
```

**Note:** This gives the container write access to the entire `.idapro` directory
on the host. If you want to keep it read-only, stick with the single-file mount.

## Troubleshooting

### Container won't start

```bash
docker logs ida-vnc
```

Check for:
- Missing installer at build time
- Port conflict (`8443` already in use)
- License mount is a directory instead of a file

### "ERROR: IDA installer not found"

Verify the installer exists at `downloads/ida-pro_94_x64linux.run`:

```bash
ls -la downloads/ida-pro_94_x64linux.run
```

### Browser shows "Connection refused"

- Container is not running: `docker ps`
- Wrong port: check `docker ps` for the correct host port mapping
- Firewall blocking the port

### Desktop icon missing

Check that `ida-pro.desktop` is in the container:

```bash
docker exec ida-vnc bash -c "ls -la ~/Desktop/ida-pro.desktop"
```

### License not recognized

Verify the mount is a file, not a directory:

```bash
docker exec ida-vnc bash -c "file ~/.idapro/ida.hexlic"
```

If it says `directory`, that means Docker created a directory because the host
path didn't exist. Delete the host directory and ensure the file exists before
starting the container.
