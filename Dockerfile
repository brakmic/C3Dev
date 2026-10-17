FROM ubuntu:26.04

###############################################################################
# (1) Configure default system locale settings
###############################################################################
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV DEBIAN_FRONTEND=noninteractive

###############################################################################
# (2) Set build arguments
###############################################################################
ARG NONROOT_USER=c3dev
ARG NODE_VERSION=24
ARG C3_VERSION=0.8.5_1
ARG C3_SHA256=939135bc6fbe9d67bf3b19c08146b93ab10996718aafff692294ae6c0b3a3f88
ARG LSD_VERSION=1.2.0
ENV NONROOT_USER=${NONROOT_USER}
ENV NODE_VERSION=${NODE_VERSION}
ENV HOME=/home/${NONROOT_USER}

###############################################################################
# (3) Install base packages
###############################################################################
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    gnupg \
    software-properties-common \
    dirmngr \
    ca-certificates \
    xz-utils \
    sudo \
    nano \
    unzip \
    build-essential \
    cmake \
    clang \
    clang-format \
    lld \
    ninja-build \
    make \
    pkg-config \
    git \
    git-lfs \
    openssh-client \
    libmicrohttpd-dev \
    python3 \
    python3-pip \
    python3-venv \
    bash-completion \
    locales \
    gdb \
    valgrind \
    net-tools \
    iproute2 \
    iputils-ping \
    dnsutils \
    strace \
    lsof \
    && rm -rf /var/lib/apt/lists/*

###############################################################################
# (4) Configure locales
###############################################################################
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen

###############################################################################
# (5) Install Node.js
###############################################################################
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g typescript tsx node-gyp yarn nodemon eslint \
    && rm -rf /var/lib/apt/lists/*

###############################################################################
# (6) Install Docker
###############################################################################
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

###############################################################################
# (7) Install lsd
###############################################################################
RUN ARCH=$(dpkg --print-architecture) && \
    wget "https://github.com/lsd-rs/lsd/releases/download/v${LSD_VERSION}/lsd_${LSD_VERSION}_${ARCH}.deb" -O /tmp/lsd.deb && \
    apt-get update && \
    apt-get install -y /tmp/lsd.deb && \
    rm /tmp/lsd.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

###############################################################################
# (8) Install WebAssembly Binary Toolkit (WABT)
###############################################################################
RUN apt-get update && \
    apt-get install -y wabt && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

###############################################################################
# (9) Install nano syntax highlighting
###############################################################################
RUN git clone --depth 1 https://github.com/scopatz/nanorc.git /tmp/nanorc \
    && mkdir -p /usr/share/nano-syntax \
    && cp -r /tmp/nanorc/* /usr/share/nano-syntax \
    && find /usr/share/nano-syntax -type f -name '*.nanorc' \
         -exec sh -c 'echo "include $1" >> /etc/nanorc' _ {} \; \
    && rm -rf /tmp/nanorc

###############################################################################
# (10) Create the C3 development user
###############################################################################
RUN useradd -m -s /bin/bash ${NONROOT_USER} \
    && echo "${NONROOT_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${NONROOT_USER} \
    && chmod 0440 /etc/sudoers.d/${NONROOT_USER} \
    && groupadd -f docker \
    && usermod -aG docker ${NONROOT_USER}

###############################################################################
# (11) Install C3 Compiler
###############################################################################
RUN mkdir -p ${HOME}/bin \
    && wget "https://github.com/c3lang/c3c/releases/download/v${C3_VERSION}/c3-linux.tar.gz" -O /tmp/c3.tar.gz \
    && echo "${C3_SHA256}  /tmp/c3.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/c3.tar.gz -C ${HOME}/bin \
    && rm /tmp/c3.tar.gz \
    && chmod +x ${HOME}/bin/c3/c3c \
    && chown -R ${NONROOT_USER}:${NONROOT_USER} ${HOME}/bin \
    && ${HOME}/bin/c3/c3c --version

###############################################################################
# (12) Set default shell to bash
###############################################################################
SHELL ["/bin/bash", "-c"]

###############################################################################
# (13) Adjust file ownership and create workspace
###############################################################################
WORKDIR /workspace
RUN mkdir -p ${HOME}/.docker && \
    chown -R ${NONROOT_USER}:${NONROOT_USER} /workspace ${HOME} && \
    chown -R ${NONROOT_USER}:docker ${HOME}/.docker

###############################################################################
# (14) Switch to the non-root user
###############################################################################
USER ${NONROOT_USER}

###############################################################################
# (15) Configure shell environment
###############################################################################
RUN cp /etc/skel/.bashrc ${HOME}/.bashrc \
    && cp /etc/skel/.profile ${HOME}/.profile

###############################################################################
# (16) Add shell aliases
###############################################################################
RUN echo -e '\
alias ll="ls -la"\n\
alias la="ls -A"\n\
alias l="ls -CF"\n\
alias gs="git status"\n\
alias ga="git add"\n\
alias gp="git push"\n\
alias gl="git log"\n\
alias rm="rm -i"\n\
alias cp="cp -i"\n\
alias mv="mv -i"\n\
alias nano="nano -c"\n\
alias ..="cd .."\n\
alias ...="cd ../.."\n\
alias ....="cd ../../.."\n\
' >> ${HOME}/.bash_aliases

###############################################################################
# (17) Configure nano and editor settings
###############################################################################
RUN echo "include /usr/share/nano-syntax/*.nanorc" >> ${HOME}/.nanorc \
    && echo "export EDITOR=nano" >> ${HOME}/.bash_profile

###############################################################################
# (18) Add C3 compiler to PATH
###############################################################################
ENV PATH=${HOME}/bin/c3:${PATH}

###############################################################################
# (19) Customize terminal prompt
###############################################################################
ENV TERM=xterm-256color
RUN echo "\
# Colorized PS1 prompt\n\
export PS1=\"\[\e[0;32m\]\u@\h\[\e[m\]:\[\e[0;34m\]\w\[\e[m\]\$ \"\
" >> ${HOME}/.bashrc

###############################################################################
# (20) Fix ownership of config files
###############################################################################
RUN chown ${NONROOT_USER}:${NONROOT_USER} \
    ${HOME}/.bashrc \
    ${HOME}/.profile \
    ${HOME}/.bash_profile \
    ${HOME}/.nanorc \
    ${HOME}/.bash_aliases

###############################################################################
# (21) Set default command
###############################################################################
CMD ["bash", "-i"]
