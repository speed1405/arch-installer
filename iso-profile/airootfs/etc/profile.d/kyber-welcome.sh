#!/bin/bash
# Shown to root on first login in the Kyber OS live environment
if [ "$(id -u)" -eq 0 ] && [ -n "$DISPLAY" ]; then
    # Already in a GUI, maybe?
    :
elif [ "$(id -u)" -eq 0 ]; then
    echo ""
    echo "  Welcome to the Kyber OS Live Environment."
    echo "  Starting the initialization sector GUI..."
    echo ""
    startx
fi
