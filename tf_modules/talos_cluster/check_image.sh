#!/bin/bash

FILE="/var/lib/vz/template/iso/talos-$1-nocloud-amd64.img"

if [ -f "$FILE" ]; then
    echo "true"
else
    echo "false"
fi