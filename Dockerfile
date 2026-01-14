FROM archlinux:latest

# Use a couple de mirrors atualizados para reduzir 404s durante o build.
RUN printf '%s\n' \
    'Server = https://mirror.math.princeton.edu/pub/archlinux/$repo/os/$arch' \
    'Server = https://mirror.pkgbuild.com/$repo/os/$arch' \
    'Server = https://mirror.clarkson.edu/archlinux/$repo/os/$arch' \
    > /etc/pacman.d/mirrorlist && \
    pacman-key --init && \
    pacman-key --populate archlinux && \
    pacman -Syyu --noconfirm archiso git grub base-devel sudo pacman-contrib && \
    pacman-key --lsign-key 'farseerfc@archlinux.org' && \
    echo '[archlinuxcn]' >> /etc/pacman.conf && \
    echo 'Server = https://repo.archlinuxcn.org/$arch' >> /etc/pacman.conf && \
    echo '' >> /etc/pacman.conf && \
    echo '[lingmo]' >> /etc/pacman.conf && \
    echo 'Server = https://lingmoos.github.io/aur/$arch' >> /etc/pacman.conf && \
    echo 'SigLevel = Optional TrustAll' >> /etc/pacman.conf && \
    pacman --noconfirm -Sy archlinuxcn-keyring && \
    useradd -m -u 1000 -G wheel builder && \
    printf '%s\n' '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/99-wheel-nopasswd && \
    chmod 0440 /etc/sudoers.d/99-wheel-nopasswd

CMD sh -c "pacman --noconfirm -Syu && \
    git clone --depth 1 https://github.com/LingmoOS/archlingmo-archiso-config /config && \
    mkarchiso -v /config/profile -o /out"
