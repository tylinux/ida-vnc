# ────────────────────────────────────────────────────────
# IDA Pro 9.4 + KasmVNC Linux Workspace Image
# ────────────────────────────────────────────────────────
FROM kasmweb/core-ubuntu-jammy:1.14.0

LABEL maintainer="tylinux"
LABEL description="IDA Pro 9.4 inside KasmVNC-powered XFCE desktop"

# ── Install runtime dependencies for Qt6 / IDA ────────
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libxcb-cursor0 \
        libxkbcommon-x11-0 \
        libxcb-keysyms1 \
        libxcb-util1 && \
    rm -rf /var/lib/apt/lists/*

# ── Install IDA Pro ───────────────────────────────────
# Installer must be staged at build/downloads/ before docker build
USER root

COPY downloads/ida-pro_94_x64linux.run /tmp/ida.run

RUN chmod +x /tmp/ida.run && \
    /tmp/ida.run --mode unattended --prefix /opt/ida-pro && \
    rm -f /tmp/ida.run && \
    chown -R 1000:1000 /opt/ida-pro

# ── Desktop Integration ────────────────────────────────
COPY --chown=1000:1000 build/ida-pro.desktop \
     /home/kasm-user/Desktop/ida-pro.desktop
COPY --chown=1000:1000 build/ida-pro.desktop \
     /usr/share/applications/ida-pro.desktop

RUN mkdir -p /home/kasm-user/.local/share/applications && \
    cp /usr/share/applications/ida-pro.desktop \
       /home/kasm-user/.local/share/applications/ida-pro.desktop && \
    chown -R 1000:1000 /home/kasm-user/.local/share/applications

# ── Environment ────────────────────────────────────────
ENV PATH="/opt/ida-pro:${PATH}"
ENV QT_QPA_PLATFORM=xcb
ENV DISPLAY=:1

# ── Startup Hook ──────────────────────────────────────
COPY --chown=1000:1000 build/custom_startup.sh /dockerstartup/
RUN chmod +x /dockerstartup/custom_startup.sh

# ── Final State ────────────────────────────────────────
USER 1000
WORKDIR /home/kasm-user/workspace

EXPOSE 6901
