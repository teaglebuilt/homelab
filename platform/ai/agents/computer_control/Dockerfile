FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    xfce4 \
    xfce4-terminal \
    tigervnc-standalone-server \
    tigervnc-common \
    dbus-x11 \
    xfonts-base \
    xfonts-100dpi \
    xfonts-75dpi \
    xfonts-cyrillic \
    firefox \
    git \
    curl \
    wget \
    vim \
    nano \
    htop \
    python3 \
    python3-pip \
    # X11 libraries needed by MCP server
    libx11-6 \
    libxext6 \
    libxrandr2 \
    libxfixes3 \
    libxinerama1 \
    libxcursor1 \
    libxi6 \
    libxtst6 \
    build-essential \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash agentdev && \
    echo "agentdev:agentdev" | chpasswd && \
    mkdir -p /home/agentdev/.vnc

# Setup VNC
COPY xstartup /home/agentdev/.vnc/xstartup
RUN chmod +x /home/agentdev/.vnc/xstartup && \
    chown -R agentdev:agentdev /home/agentdev

# Create workspace directory
RUN mkdir -p /home/agentdev/workspace && \
    chown -R agentdev:agentdev /home/agentdev/workspace

USER agentdev
WORKDIR /home/agentdev

# VNC startup script
COPY --chown=agentdev:agentdev entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 5900

ENTRYPOINT ["/entrypoint.sh"]
