# Build & Deployment Guide

## Prerequisites

### On Your Development Machine
- SSH access to a remote Linux x86_64 host (called "Builder" in this guide)
- `rsync` (macOS built-in)
- `make` (macOS built-in or via Xcode CLI tools)

### On The Builder (Linux x86_64)
- Docker Engine installed and running
- User has `docker` group membership (no sudo required)
- IDA Pro installer placed on the Builder at the project `downloads/` directory
- IDA license file (`ida.hexlic`) available somewhere on the Builder (optional)
- Port `8443` (or your `HOST_PORT`) accessible from your browser

## Quick Start

### 1. Configure Environment

Copy `.env` and edit with your values:

```bash
cd IDA-VNC
cp .env .env.local   # .env is already gitignored
# Edit .env or .env.local with your real paths
```

Key variables:

| Variable | Default | What to set |
|----------|---------|-------------|
| `BUILDER_HOST` | `Builder` | SSH host alias or IP of your Linux builder |
| `IDA_INSTALLER` | `downloads/ida-pro_94_x64linux.run` | Path to the installer on the Builder (relative to project root) |
| `IDA_HEXLIC_HOST_PATH` | `~/ida.hexlic` | Absolute path to your license file on the Builder |
| `WORKSPACE_HOST_PATH` | `~/IDA-workspace` | Absolute path to persistent workspace on the Builder |
| `HOST_PORT` | `8443` | Port mapped on the Builder |
| `VNC_PASSWORD` | `changeme` | **Change this.** |

### 2. Place The Installer

The installer (~627 MB) must be on the Builder before building. Do **not** commit
it to git — `downloads/*.run` is already gitignored.

```bash
# On the Builder
mkdir -p ~/projects/IDA-VNC/downloads
cp /path/to/your/ida-pro_94_x64linux.run ~/projects/IDA-VNC/downloads/
```

If your installer lives elsewhere on the Builder, set `IDA_INSTALLER` in `.env`
to the absolute path, e.g.:

```bash
IDA_INSTALLER=/home/you/Downloads/ida-pro_94_x64linux.run
```

### 3. Build & Deploy

```bash
make all    # sync + build
make run    # start container
```

### 4. Access IDA Pro

Open your browser:

```
https://<builder-ip>:8443
```

- Accept the self-signed certificate warning.
- Enter the VNC username: **`kasm_user`**
- Enter the VNC password: whatever you set in `VNC_PASSWORD` (default: `changeme`)
- You should see the XFCE desktop. Click the **IDA Pro 9.4** icon on the desktop
  or open it from the Applications menu.

### 5. Transfer Files To Analyze

**Option A — Pre-mount at startup**

Place files in the directory you set as `WORKSPACE_HOST_PATH` on the Builder
before running `make run`. They will be available inside the container at
`~/workspace`.

**Option B — After startup — via Docker cp**

```bash
ssh <builder-host>
docker cp ./sample.bin ida-vnc:/home/kasm-user/workspace/
```

**Option C — After startup — via Kasm file upload**

Use the KasmVNC sidebar (left edge of browser) → Files → Upload.

### 6. Stop & Cleanup

```bash
make stop     # stop and remove container
make clean    # remove image
make prune    # deep cleanup (containers, images, volumes)
```

## Advanced: Full Config Persistence

By default, only the `workspace` and `ida.hexlic` are persistent. If you want
IDA plugins, settings, and history to survive container restarts, change the
license mount from a single file to a directory:

```bash
# On the Builder
mkdir -p ~/IDA-config
# Copy your license there
cp ~/ida.hexlic ~/IDA-config/ida.hexlic
```

Then in `.env`, set:

```bash
IDA_HEXLIC_HOST_PATH=/home/you/IDA-config
# (remove the :ro suffix in the run command or use compose if you want
# the container to write back to the host)
```

**Note:** This gives the container write access to the entire `.idapro` directory
on the host. If you want to keep it read-only, stick with the single-file mount.

## Troubleshooting

### Container won't start

```bash
make logs
```

Check for:
- Missing license file warning (non-fatal, but IDA will be in trial mode)
- Port conflict (`8443` already in use)

### "ERROR: IDA installer not found"

Verify the installer exists at the path defined by `IDA_INSTALLER`:

```bash
# On the Builder
ls <project-root>/downloads/ida-pro_94_x64linux.run
# or if you set a custom absolute path:
ls <your-absolute-path>/ida-pro_94_x64linux.run
```

### Browser shows "Connection refused"

- Builder firewall blocking port `8443` (or your `HOST_PORT`)
- Container crashed; check `make logs`
- Wrong IP — use the Builder's IP address, not localhost

### Desktop icon missing

Check that `ida-pro.desktop` is in the container:

```bash
make shell
ls -la ~/Desktop/ida-pro.desktop
```

### License not recognized

Verify the mount is a file, not a directory:

```bash
make shell
ls -la ~/.idapro/ida.hexlic
file ~/.idapro/ida.hexlic
```

If you see `~/.idapro/ida.hexlic: directory`, that means Docker created a
directory because the host path didn't exist at runtime. Make sure your license
file exists on the host before starting the container.

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
