#!/bin/bash

set -e

if [ -n "$VNC_PASSWORD" ]; then
    echo "$VNC_PASSWORD" | vncpasswd -f > /home/agentdev/.vnc/passwd
else
    echo "agentdev" | vncpasswd -f > /home/agentdev/.vnc/passwd
fi
chmod 600 /home/agentdev/.vnc/passwd

# Set resolution
RESOLUTION=${RESOLUTION:-1920x1080}

# Start VNC server
exec vncserver :0 \
    -geometry $RESOLUTION \
    -depth 24 \
    -localhost no \
    -SecurityTypes VncAuth \
    -fg
