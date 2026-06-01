# Dockerfile for testing the Hyprland installer on Arch Linux.
#
# Build from repo root:
#   docker build -f .install/Dockerfile -t arch-hyprland-test .
#
# Run:
#   docker run -it --rm arch-hyprland-test

FROM archlinux:latest

RUN pacman -Syu --noconfirm --needed sudo git base-devel wget

RUN useradd --create-home --shell /bin/bash testuser
RUN echo "testuser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

COPY .install/installer.sh /home/testuser/.install/installer.sh
COPY .install/packages.txt /home/testuser/.install/packages.txt
COPY .install/packages-aur.txt /home/testuser/.install/packages-aur.txt
RUN chown -R testuser:testuser /home/testuser/.install && \
    chmod +x /home/testuser/.install/installer.sh

USER testuser
WORKDIR /home/testuser

CMD ["/bin/bash"]
