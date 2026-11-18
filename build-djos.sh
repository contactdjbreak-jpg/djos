#!/usr/bin/env bash
# build-djos.sh : construit l'ISO de DJOS (base Debian + GNOME, look macOS)
# À lancer sur Debian/Ubuntu (ou une VM) avec : sudo bash build-djos.sh
# Prévoir ~15 Go libres, une connexion Internet et 20 à 60 minutes.
set -euo pipefail

if [ "$EUID" -ne 0 ]; then echo "Lance avec sudo."; exit 1; fi

apt-get update
apt-get install -y live-build debootstrap git xorriso squashfs-tools

WORK=/opt/djos-build
rm -rf "$WORK" && mkdir -p "$WORK" && cd "$WORK"

lb config \
  --distribution trixie \
  --architectures amd64 \
  --binary-images iso-hybrid \
  --debian-installer none \
  --archive-areas "main contrib non-free-firmware" \
  --iso-volume "DJOS" \
  --iso-application "DJOS" \
  --iso-publisher "DJOS" \
  --image-name "djos" \
  --bootappend-live "boot=live components quiet splash"

# ---------- Paquets ----------
mkdir -p config/package-lists
cat > config/package-lists/djos.list.chroot <<'EOF'
task-gnome-desktop
gnome-tweaks
gnome-shell-extension-dashtodock
gnome-shell-extension-appindicator
gnome-software
gnome-control-center
network-manager-gnome
bluez
gnome-bluetooth-sushi
firefox-esr
fonts-inter
plymouth
plymouth-themes
git
sassc
libglib2.0-dev-bin
firmware-linux
firmware-iwlwifi
firmware-realtek
firmware-atheros
calamares
calamares-settings-debian
sudo
EOF

# ---------- Réglages par défaut (dconf) ----------
mkdir -p config/includes.chroot/etc/dconf/profile
mkdir -p config/includes.chroot/etc/dconf/db/local.d

cat > config/includes.chroot/etc/dconf/profile/user <<'EOF'
user-db:user
system-db:local
EOF

cat > config/includes.chroot/etc/dconf/db/local.d/00-djos <<'EOF'
[org/gnome/desktop/interface]
gtk-theme='WhiteSur-Dark'
icon-theme='WhiteSur-dark'
font-name='Inter 11'
enable-animations=true
color-scheme='prefer-dark'
clock-show-weekday=true

[org/gnome/desktop/wm/preferences]
button-layout='close,minimize,maximize:'

[org/gnome/shell]
enabled-extensions=['dash-to-dock@micxgx.gmail.com','appindicatorsupport@rgcjonas.gmail.com']
favorite-apps=['firefox-esr.desktop','org.gnome.Nautilus.desktop','org.gnome.Software.desktop','org.gnome.Settings.desktop','org.gnome.Terminal.desktop']

[org/gnome/shell/extensions/dash-to-dock]
dock-position='BOTTOM'
extend-height=false
dock-fixed=false
autohide=true
intellihide=true
transparency-mode='DYNAMIC'
dash-max-icon-size=56
click-action='minimize-or-previews'
EOF

# ---------- Identité DJOS ----------
mkdir -p config/includes.chroot/etc
cat > config/includes.chroot/etc/os-release <<'EOF'
PRETTY_NAME="DJOS"
NAME="DJOS"
VERSION="1.0"
VERSION_ID="1.0"
ID=djos
ID_LIKE=debian
HOME_URL=""
EOF
echo "DJOS 1.0 \n \l" > config/includes.chroot/etc/issue
echo "djos" > config/includes.chroot/etc/hostname

# ---------- Hooks (exécutés pendant la construction) ----------
mkdir -p config/hooks/live

cat > config/hooks/live/0100-theme.hook.chroot <<'EOF'
#!/bin/bash
set -e
cd /tmp
git clone --depth=1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git
git clone --depth=1 https://github.com/vinceliuice/WhiteSur-icon-theme.git
(cd WhiteSur-gtk-theme && ./install.sh -d /usr/share/themes)
(cd WhiteSur-icon-theme && ./install.sh -d /usr/share/icons)
rm -rf /tmp/WhiteSur-*
dconf update
EOF

cat > config/hooks/live/0200-plymouth.hook.chroot <<'EOF'
#!/bin/bash
plymouth-set-default-theme -R spinner || true
EOF

chmod +x config/hooks/live/*.hook.chroot

# ---------- Construction ----------
lb build 2>&1 | tee build.log

ls -lh ./*.iso
echo
echo "Terminé. Ton ISO est dans : $WORK"
echo "Grave-la sur clé avec balenaEtcher ou Rufus (mode DD/ISO)."
