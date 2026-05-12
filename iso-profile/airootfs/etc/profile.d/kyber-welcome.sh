#!/bin/bash
# Shown to root on first login in the Kyber OS live environment
if [ "$(id -u)" -eq 0 ] && [ -f /root/install.sh ]; then
    echo ""
    echo "  Run /root/install.sh to begin the Kyber OS installation."
    echo ""
fi
