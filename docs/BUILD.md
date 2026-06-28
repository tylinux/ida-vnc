# Build & Deployment Guide

## Prerequisites

### On Mac (Development)
- SSH access to `Builder` (configured in `~/.ssh/config` as `Host Builder`)
- `rsync` (macOS built-in)
- `make` (macOS built-in or via Xcode CLI tools)

### On Builder (Linux x86_64)
- Docker Engine installed and running
- User has `docker` group membership (no sudo required)
- IDA Pro installer at `/home/tylinux/Downloads/qbittorrent/ida94b1/ida-pro_94_x64linux.run`
- IDA license file at `/home/tylinux/ida.hexlic` (or wherever you put it)
- Port `8443` (or your `HOST_PORT`) accessible from your Mac

## Quick Start

### 1. Configure Environment

Copy `.env` and edit values:

```bash
cp .env .env.local   # or just edit .env directly (it's gitignored)
# Edit .env to match your Builder setup
```

Key variables:

| Variable | Default | What to change |
|----------|---------|----------------|
| `BUILDER_HOST` | `Builder` | SSH host alias or IP |
| `IDA_INSTALLER_SRC` | `/home/tylinux/.../ida-pro_94_x64linux.run` | Path on Builder |
| `IDA_HEXLIC_HOST_PATH` | `/home/tylinux/ida.hexlic` | Your license file path on Builder |
| `WORKSPACE_HOST_PATH` | `/home/tylinux/IDA-workspace` | Where persistent files live on Builder |
| `HOST_PORT` | `8443` | Port mapped on Builder |

### 2. One-Command Build & Deploy

```bash
make all    # sync + build
make run    # start container
```

### 3. Access IDA Pro

Open browser on Mac:

```
https://<Builder-IP>:8443
```

Accept the self-signed certificate warning. Enter the VNC password (default: `changeme`, set via `VNC_PASSWORD` in `.env`).

You should see the XFCE desktop. Click the **IDA Pro 9.4** icon on the desktop or in the menu.

### 4. Transfer Files to Analyze

**Option A: Pre-mount at startup**

Place files in `~/IDA-workspace` on Builder before `make run`. They're already bind-mounted.

**Option B: After startup — via Docker cp**

```bash
ssh Builder
docker cp ./sample.bin ida-vnc:/home/kasm-user/workspace/
```

**Option C: After startup — via Kasm file upload**

Use the KasmVNC sidebar (left edge of browser) → Files → Upload.

### 5. Stop & Cleanup

```bash
make stop     # stop and remove container
make clean    # remove image
make prune    # deep cleanup (containers, images, volumes)
```

## Advanced: Full Config Persistence

By default, only the `workspace` and `ida.hexlic` are persistent. If you want IDA plugins, settings, and history to survive container restarts, change the license mount from a single file to a directory:

```bash
# On Builder
mkdir -p ~/IDA-config
# Copy your license there
cp ~/ida.hexlic ~/IDA-config/ida.hexlic
```

Then in `.env`, set:

```bash
IDA_HEXLIC_HOST_PATH=/home/tylinux/IDA-config
# (remove the :ro suffix in the run command or use compose)
```

**Note:** This gives the container write access to the entire `.idapro` directory on the host. If you want to keep it read-only, stick with the single-file mount.

## Troubleshooting

### Container won't start

```bash
make logs
```

Check for:
- Missing license file warning (non-fatal, but IDA will be in trial mode)
- Port conflict (`8443` already in use)

### "ERROR: IDA installer not found"

Verify `IDA_INSTALLER_SRC` in `.env` points to the actual file on Builder:

```bash
ssh Builder ls -la /home/tylinux/Downloads/qbittorrent/ida94b1/ida-pro_94_x64linux.run
```

### Browser shows "Connection refused"

- Builder firewall blocking port `8443`
- Container crashed; check `make logs`

### Desktop icon missing

Check that `ida-pro.desktop` is in the container:

```bash
make shell
ls -la ~/Desktop/ida-pro.desktop
```

### License not recognized

Verify the mount:

```bash
make shell
ls -la ~/.idapro/ida.hexlic
cat ~/.idapro/ida.hexlic | head -c 100
```

## Makefile Reference

| Target | Description |
|--------|-------------|
| `make all` | `sync` + `build` |
| `make sync` | Push code to Builder |
| `make build` | Build Docker image on Builder |
| `make run` | Start container on Builder |
| `make stop` | Stop and remove container |
| `make restart` | `stop` + `run` |
| `make shell` | Bash into running container |
| `make logs` | Tail container logs |
| `make clean` | Remove image from Builder |
| `make prune` | Deep cleanup |
| `make help` | Show all targets |
