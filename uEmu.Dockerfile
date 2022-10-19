FROM ubuntu:20.04

# Install utils.
RUN apt-get update &&                           \
    DEBIAN_FRONTEND=noninteractive              \
    apt-get install -y --no-install-recommends  \
    git zsh curl wget openssh-server apt-utils

# Configure time zone.
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install uEmu run-time dependencies.
RUN dpkg --add-architecture i386                                       &&   \
    apt-get update && apt-get -y dist-upgrade                          &&   \
    apt-get install -y --no-install-recommends build-essential              \
    cmake wget texinfo flex bison python-dev python3-dev python3-venv       \
    python3-distro mingw-w64 lsb-release

# Install uEmu build dependencies.
RUN apt-get update && DEBIAN_FRONTEND=noninteractive                        \
    apt-get install -y --no-install-recommends libdwarf-dev libelf-dev      \
    libelf-dev:i386 libboost-dev zlib1g-dev libjemalloc-dev nasm            \
    pkg-config libmemcached-dev libpq-dev libc6-dev-i386 binutils-dev       \
    libboost-system-dev libboost-serialization-dev libboost-regex-dev       \
    libbsd-dev libpixman-1-dev libncurses5                                  \
    libglib2.0-dev libglib2.0-dev:i386 python3-docutils libpng-dev          \
    gcc-multilib g++-multilib gcc-9 g++-9 libtinfo5

# Install git repo.
RUN mkdir -p /root/.bin && PATH="/root/.bin:${PATH}"                                    \
    curl https://storage.googleapis.com/git-repo-downloads/repo > /root/.bin/repo  &&   \
    chmod a+rx /root/.bin/repo

# Set up env and directories.

ENV uEmuDIR=/root/uemu

RUN mkdir -p /root/uemu/build && cd $uEmuDIR                                &&  \
    /root/.bin/repo init -u https://github.com/MCUSec/manifest.git -b uEmu  &&  \
    /root/.bin/repo sync

# Fix permissions
RUN chmod +x $uEmuDIR/s2e/libs2e/configure

# Get ptracearm.h
RUN wget -P /usr/include/x86_64-linux-gnu/asm \
    https://raw.githubusercontent.com/MCUSec/uEmu/main/ptracearm.h

# Start build process
RUN cd $uEmuDIR/build && make -f $uEmuDIR/Makefile  &&  \
    make -f $uEmuDIR/Makefile install               &&  \
    cd $uEmuDIR/AFL && make && make install

# Install Python Jinja lib
RUN apt-get update &&                           \
    DEBIAN_FRONTEND=noninteractive              \
    apt-get install -y --no-install-recommends  \
    python3-pip && pip3 install -U pip &&       \
    pip install jinja2

# Set up environment for new connections
RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"         && \
    mkdir -p /root/.zsh                                                                          && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git                              \
        /root/.zsh/zsh-syntax-highlighting.git                                                   && \
    git clone https://github.com/zsh-users/zsh-autosuggestions.git                                  \
        /root/.zsh/zsh-autosuggestions.git                                                       && \
    echo 'source /root/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' >> /root/.zshrc && \
    echo 'source /root/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh'         >> /root/.zshrc && \
    echo "export uEmuDIR=$uEmuDIR" >> ~/.zshrc

# Installation done, get all repositories
RUN cd $uEmuDIR                                                         && \
    git clone https://github.com/MCUSec/uEmu-unit_tests.git             && \
    git clone https://github.com/MCUSec/uEmu-real_world_firmware.git    && \
    git clone https://github.com/MCUSec/uEmu.git
