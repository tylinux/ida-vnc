#!/usr/bin/env bash
set -e

HEXLIC_PATH="/home/kasm-user/.idapro/ida.hexlic"

# ── License check ─────────────────────────────────────
if [[ ! -f "$HEXLIC_PATH" ]]; then
    echo "============================================================"
    echo "WARNING: IDA license file not found at $HEXLIC_PATH"
    echo ""
    echo "Please mount your ida.hexlic when starting the container:"
    echo "  docker run -v /host/path/ida.hexlic:$HEXLIC_PATH:ro ..."
    echo ""
    echo "IDA will start in evaluation mode."
    echo "============================================================"
else
    echo "IDA license file detected: $HEXLIC_PATH"
    # Ensure correct permissions (readable, not executable)
    chmod 644 "$HEXLIC_PATH" 2>/dev/null || true
fi

# ── Ensure workspace and config directories exist ─────
mkdir -p /home/kasm-user/workspace
mkdir -p /home/kasm-user/.idapro

# ── Done. Kasm VNC startup will proceed via vnc_startup.sh ──
# (This script is called by vnc_startup.sh's custom_startup() function)

