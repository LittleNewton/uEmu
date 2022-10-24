ARG BASE_IMAGE="ubuntu:20.04"

### BASE IMAGE
FROM $BASE_IMAGE
ARG BASE_IMAGE

# Copy dependencies lists into container. Note this
# will rarely change so caching should still work well
COPY ./dependencies/${BASE_IMAGE}*.txt /tmp/

# Install utilities. -- Stage 0
RUN [ -e /tmp/${BASE_IMAGE}_utils.txt ] && \
    apt-get -qq update && \
    DEBIAN_FRONTEND=noninteractive apt-get -qq install -y --no-install-recommends curl $(cat /tmp/${BASE_IMAGE}_utils.txt | grep -o '^[^#]*') && \
    apt-get clean

# Install runtime dependencies. Firstly, Configure time zone.
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install uEmu run-time dependencies.
RUN [ -e /tmp/${BASE_IMAGE}_base.txt ] && \
    dpkg --add-architecture i386 && \
    apt-get -qq update && apt-get -y dist-upgrade &&\
    DEBIAN_FRONTEND=noninteractive apt-get -qq install -y --no-install-recommends curl $(cat /tmp/${BASE_IMAGE}_base.txt | grep -o '^[^#]*') && \
    apt-get clean

# Install uEmu build dependencies.
RUN [ -e /tmp/${BASE_IMAGE}_build.txt ] && \
    apt-get -qq update && \
    DEBIAN_FRONTEND=noninteractive apt-get -qq install -y --no-install-recommends curl $(cat /tmp/${BASE_IMAGE}_build.txt | grep -o '^[^#]*') && \
    apt-get clean && \
    python3 -m pip install --upgrade --no-cache-dir "pip" && \
    python3 -m pip install --upgrade --no-cache-dir "jinja2"

# Install git repo.
RUN mkdir -p /root/.bin && PATH="/root/.bin:${PATH}"                                    \
    curl https://storage.googleapis.com/git-repo-downloads/repo > /root/.bin/repo  &&   \
    chmod a+rx /root/.bin/repo

# Set up env and directories.
ENV uEmuDIR=/root/uemu

# Sync uEmu core repositories.
RUN mkdir -p ${uEmuDIR}/build && cd $uEmuDIR                                &&  \
    /root/.bin/repo init -u https://github.com/MCUSec/manifest.git -b uEmu  &&  \
    /root/.bin/repo sync && chmod +x $uEmuDIR/s2e/libs2e/configure

# Get ptracearm.h
RUN wget -P /usr/include/x86_64-linux-gnu/asm \
    https://raw.githubusercontent.com/MCUSec/uEmu/main/ptracearm.h

# Start uEmu building.
RUN cd $uEmuDIR/build && make -f $uEmuDIR/Makefile  &&  \
    make -f $uEmuDIR/Makefile install               &&  \
    cd $uEmuDIR/AFL && make -j "$(nproc)" && make install

# Set up environment for new connections.
RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"         && \
    mkdir -p /root/.zsh                                                                          && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git                              \
        /root/.zsh/zsh-syntax-highlighting                                                       && \
    git clone https://github.com/zsh-users/zsh-autosuggestions.git                                  \
        /root/.zsh/zsh-autosuggestions                                                           && \
    echo 'source /root/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' >> /root/.zshrc && \
    echo 'source /root/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh'         >> /root/.zshrc && \
    echo "export uEmuDIR=$uEmuDIR" >> ~/.zshrc                                                   && \
    sed -i 's~:/bin/bash$~:/usr/bin/zsh~' /etc/passwd

# Download all test-unit and uEmu itself from GitHub
RUN cd $uEmuDIR                                                         && \
    git clone https://github.com/MCUSec/uEmu-unit_tests.git             && \
    git clone https://github.com/MCUSec/uEmu-real_world_firmware.git    && \
    git clone https://github.com/MCUSec/uEmu.git

# Enable ssh service
RUN service ssh start
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
