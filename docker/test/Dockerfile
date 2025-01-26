# This Dockerfile sets up an environment for testing the functionality defined in this repository.
# It is not intended for production or deployment purposes.

FROM archlinux:latest

RUN pacman-key --init && \
    pacman-key --populate archlinux && \
    pacman -Syu --noconfirm

RUN pacman -S --noconfirm \
    act \
    bats-assert bats-file bats-support \
    nodejs npm

WORKDIR /workspace

CMD ["/bin/bash"]
