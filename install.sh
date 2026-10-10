#!/bin/bash

# Installs the dslr-webcam CLI, systemd user service, udev autostart rule, and
# v4l2loopback config. Safe to re-run. Run from the repo or from the plugin
# folder that `omarchy plugin add` cloned into ~/.config/omarchy/plugins/.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

step() { printf '\e[1m==> %s\e[0m\n' "$*"; }

step "Installing packages"
PKGS=(gphoto2 ffmpeg v4l-utils psmisc v4l2loopback-dkms)
if command -v omarchy-pkg-add >/dev/null 2>&1; then
  omarchy-pkg-add "${PKGS[@]}"
else
  sudo pacman -S --needed --noconfirm "${PKGS[@]}"
fi

step "Linking dslr-webcam into $BIN_DIR"
mkdir -p "$BIN_DIR"
ln -sfn "$ROOT/bin/dslr-webcam" "$BIN_DIR/dslr-webcam"

step "Configuring v4l2loopback"
if grep -qs 'options[[:space:]]\+v4l2loopback' /etc/modprobe.d/*.conf; then
  echo "    existing v4l2loopback options found in /etc/modprobe.d, leaving them alone"
else
  sudo install -Dm644 "$ROOT/modprobe/dslr-webcam.conf" /etc/modprobe.d/dslr-webcam.conf
fi
if ! grep -qsx 'v4l2loopback' /etc/modules-load.d/*.conf; then
  echo v4l2loopback | sudo tee /etc/modules-load.d/dslr-webcam.conf >/dev/null
fi
lsmod | grep -q '^v4l2loopback' || sudo modprobe v4l2loopback

step "Installing udev autostart rule"
sudo install -Dm644 "$ROOT/udev/90-dslr-webcam.rules" /etc/udev/rules.d/90-dslr-webcam.rules
sudo udevadm control --reload

step "Installing systemd user service"
mkdir -p "$UNIT_DIR"
install -m644 "$ROOT"/systemd/dslr-webcam{.service,-config.path,-config.service} "$UNIT_DIR/"
systemctl --user daemon-reload
systemctl --user enable dslr-webcam.service >/dev/null
systemctl --user enable --now dslr-webcam-config.path >/dev/null

step "Creating settings file"
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dslr-webcam/config"
if [[ -f $CONFIG_FILE ]]; then
  echo "    keeping existing $CONFIG_FILE"
else
  install -Dm644 "$ROOT/config.example" "$CONFIG_FILE"
  echo "    $CONFIG_FILE (edit with: dslr-webcam config)"
fi

step "Starting"
"$BIN_DIR/dslr-webcam" on || true
echo
"$BIN_DIR/dslr-webcam" doctor || true
