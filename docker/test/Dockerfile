# This Dockerfile sets up an environment for testing the functionality defined in this repository.
# It is not intended for production or deployment purposes.

# Use Arch Linux as base image
FROM archlinux:base

# Initialize and update keyring before running a full system upgrade
RUN pacman-key --init && \
    pacman-key --populate archlinux && \
    pacman -Sy --noconfirm archlinux-keyring && \
    pacman -Syu --noconfirm

# Install required packages
RUN pacman -S --noconfirm --needed \
    act \
    bats-assert bats-file bats-support \
    nodejs npm \
    kcov \
    git \
    lvm2 \
    btrfs-progs

# Set working directory
WORKDIR /workspace

# Set default shell
SHELL ["/bin/bash", "-c"]

# Default command
CMD ["/bin/bash"]
