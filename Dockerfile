FROM starlabio/ubuntu-base:1.2
MAINTAINER Doug Goldstein <doug@starlab.io>

# setup linkers for Cargo
RUN mkdir -p /root/.cargo/
RUN echo "[target.aarch64-unknown-linux-gnu]\r\nlinker = \"aarch64-linux-gnu-gcc\"" >> /root/.cargo/config
RUN echo "[target.arm-unknown-linux-gnueabihf]\r\nlinker = \"arm-linux-gnueabihf-gcc\"" >> /root/.cargo/config

ENV PATH "/root/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# install rustup
RUN curl https://sh.rustup.rs -sSf > rustup-install.sh && \
    sh ./rustup-install.sh -y --default-toolchain 1.15.1-x86_64-unknown-linux-gnu && \
    rm rustup-install.sh

# Install AARCH64 Rust
RUN /root/.cargo/bin/rustup target add aarch64-unknown-linux-gnu
# Install 32-bit ARM Rust
RUN /root/.cargo/bin/rustup target add arm-unknown-linux-gnueabihf
# Install Rust nightly
RUN /root/.cargo/bin/rustup toolchain install nightly-2017-09-13-x86_64-unknown-linux-gnu

# Install rustfmt / cargo fmt for testing
RUN cargo install --root /usr/local rustfmt --vers 0.8.0

# Get libcurl.so.4 needed by latest cargo
RUN apt-get update && \
    apt-get --quiet --yes install libcurl3 && \
        apt-get autoremove -y && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists* /tmp/* /var/tmp/*

# Install clippy
run /root/.cargo/bin/rustup run nightly-2017-09-13 -- cargo install --root /usr/local clippy --vers 0.0.160

# setup fetching arm packages
RUN dpkg --add-architecture arm64 && dpkg --add-architecture armhf

# Ubuntu can't be an adult with their sources list for arm
RUN sed -e 's:deb h:deb [arch=amd64] h:' -e 's:deb-src h:deb-src [arch=amd64] h:' -i /etc/apt/sources.list && \
        find /etc/apt/sources.list.d/ -type f -exec sed -e 's:deb h:deb [arch=amd64] h:' -e 's:deb-src h:deb-src [arch=amd64] h:' -i {} \; && \
        sed -e 's:arch=amd64:arch=armhf,arm64:' -e 's:security:ports:' -e 's://.*archive://ports:' -e 's:/ubuntu::' /etc/apt/sources.list | grep 'ubuntu.com' | grep -v '\-ports' | tee /etc/apt/sources.list.d/arm.list

# package depends
RUN apt-get update && \
    apt-get --quiet --yes install \
        checkpolicy autoconf-archive libtool \
        libnl-3-dev texinfo libnl-utils software-properties-common \
        libnl-cli-3-dev libbz2-dev libpci-dev m4 cmake \
        gettext bin86 bcc acpica-tools uuid-dev ncurses-dev \
        libaio-dev libyajl-dev libkeyutils-dev bc u-boot-tools libncurses-dev \
        linux-headers-generic clang-3.7 clang-format-3.7 cppcheck libtspi-dev \
        vim-common lcov liblzma-dev gnu-efi \
        gcc-arm-linux-gnueabihf gcc-aarch64-linux-gnu libssl-dev:armhf \
        libssl-dev:arm64 libkeyutils1:arm64 libkeyutils-dev:arm64 \
        libkeyutils1:armhf libkeyutils-dev:armhf libbsd-dev && \
        apt-get autoremove -y && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists* /tmp/* /var/tmp/*

# Install behave and hamcrest for testing
RUN pip install behave pyhamcrest

# We need to install TPM 2.0 tools
RUN curl -sSfL https://github.com/01org/tpm2-tss/releases/download/1.2.0/tpm2-tss-1.2.0.tar.gz > tpm2-tss-1.2.0.tar.gz && \
    tar -zxf tpm2-tss-1.2.0.tar.gz && \
    cd tpm2-tss-1.2.0 && \
    ./configure && \
    make && \
    make install && \
    cd .. && \
    rm -rf tpm2-tss-1.2.0
