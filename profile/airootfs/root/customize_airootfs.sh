#!/usr/bin/env bash
set -euo pipefail

mkdir -p /etc/xdg
cat > /etc/xdg/kwinrc <<'EOF'
[org.kde.kdecoration3]
library=org.kde.breeze
theme=Breeze
EOF

mkdir -p /usr/share/xsessions
cat > /usr/share/xsessions/lingmo-xsession.desktop <<'EOF'
[Desktop Entry]
Type=Application
Exec=/usr/local/bin/lingmo-session-wrapper
TryExec=/usr/bin/lingmo-session
Name=Lingmo Desktop
Keywords=session
Comment=session
EOF

# Ensure the live user has a real home directory with the expected skeleton.
# ArchISO may ship the user in /etc/passwd without creating /home/<user>.
if id -u lingmo >/dev/null 2>&1; then
  install -d -m 0755 -o lingmo -g lingmo /home/lingmo
  cp -a /etc/skel/. /home/lingmo/ 2>/dev/null || true
  install -d -m 0755 -o lingmo -g lingmo /home/lingmo/Desktop
  chown -R lingmo:lingmo /home/lingmo
fi

if ! command -v calamares >/dev/null 2>&1; then
  cache_dir=/tmp/pacman-cache
  mkdir -p "$cache_dir"
  pacman_conf=/tmp/pacman-no-checkspace.conf
  cp /etc/pacman.conf "$pacman_conf"
  sed -i '/^CheckSpace$/d' "$pacman_conf"

  # The ISO build may have run with a working dir bind-mounted from the host.
  # In that case, ownership/permissions of the keyring directory can get messed up,
  # which breaks signature verification in arch-chroot.
  rm -rf /etc/pacman.d/gnupg
  pacman-key --init
  pacman-key --populate archlinux archlinuxcn || pacman-key --populate archlinux

  pacman --config "$pacman_conf" --cachedir "$cache_dir" -Syy --noconfirm --needed git base-devel

  if ! id -u builder >/dev/null 2>&1; then
    useradd -m builder
  fi
  usermod -aG wheel builder

  install -d -m 0755 -o builder -g builder /home/builder/.config/pacman
  cat > /home/builder/.config/pacman/makepkg.conf <<'EOF'
PACMAN='/usr/bin/pacman'
PACMAN_OPTS=(--noconfirm --needed --config /tmp/pacman-no-checkspace.conf --cachedir /tmp/pacman-cache)
EOF
  chown builder:builder /home/builder/.config/pacman/makepkg.conf

  install -d -m 0755 -o builder -g builder /tmp/aur
  su - builder -c '
    set -euo pipefail
    cd /tmp/aur
    rm -rf calamares
    git clone --depth 1 https://aur.archlinux.org/calamares.git
    cd calamares
    MAKEFLAGS="-j$(nproc)" makepkg -s --noconfirm
  '

  calamares_pkg="$(ls -1 /tmp/aur/calamares/calamares-*.pkg.tar.* | grep -v -- '-debug-' | head -n 1)"
  pacman --config "$pacman_conf" --cachedir "$cache_dir" -U --noconfirm "$calamares_pkg"
fi
