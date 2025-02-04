# This Dockerfile sets up an environment for testing the functionality defined in this repository.
# It is not intended for production or deployment purposes.

# Use Arch Linux as base image
FROM archlinux:latest

# Initialize and update keyring before running a full system upgrade
RUN pacman-key --init && \
    pacman-key --populate archlinux && \
    pacman -Syu --noconfirm

# Install required packages
RUN pacman -S --noconfirm --needed \
    act \
    bats-assert bats-file bats-support \
    nodejs npm \
    kcov

# Add non-root user
RUN useradd -m -s /bin/bash testuser

# Ensure testuser has permissions to write to /__w
RUN mkdir -p /__w && chown -R testuser:testuser /__w

# Use testuser for security
USER testuser

# Set working directory
WORKDIR /workspace

# Set default shell
SHELL ["/bin/bash", "-c"]

# Default command
CMD ["/bin/bash"]
