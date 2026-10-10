#!/bin/bash

# Removes everything install.sh added. Leaves packages and an existing
# v4l2loopback config that install.sh did not create.

set -uo pipefail

UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

systemctl --user disable --now dslr-webcam.service dslr-webcam-config.path 2>/dev/null
rm -f "$UNIT_DIR"/dslr-webcam{.service,-config.path,-config.service} "$HOME/.local/bin/dslr-webcam"
systemctl --user daemon-reload
sudo rm -f /etc/udev/rules.d/90-dslr-webcam.rules /etc/modprobe.d/dslr-webcam.conf /etc/modules-load.d/dslr-webcam.conf
sudo udevadm control --reload
echo "Removed. Config and state remain in ~/.config/dslr-webcam and ~/.local/state/dslr-webcam."
