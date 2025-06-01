FROM ubuntu:24.04

###############################################################################
# (1) Configure default system locale settings
###############################################################################
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

###############################################################################
# (2) Set build arguments
###############################################################################
ARG NONROOT_USER=c3dev
ARG NODE_VERSION=22
ENV NONROOT_USER=${NONROOT_USER}
ENV NODE_VERSION=${NODE_VERSION}
ENV HOME=/home/${NONROOT_USER}

###############################################################################
# (3) Install base packages
###############################################################################
RUN apt update && apt install -y --no-install-recommends \
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
    gcc-14 \
    g++-14 \
    cmake \
    clang-format \
    ninja-build \
    make \
    git \
    git-lfs \
    python3 \
    python3-pip \
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
# (4) Switch default compilers to GCC/G++ 14
###############################################################################
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 50 \
    && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-14 60 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 50 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-14 60 \
    && update-alternatives --set gcc /usr/bin/gcc-14 \
    && update-alternatives --set g++ /usr/bin/g++-14

###############################################################################
# (5) Configure locales
###############################################################################
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen

###############################################################################
# (6) Install Node.js
###############################################################################
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt install -y nodejs \
    && npm install -g typescript tsx node-gyp yarn nodemon eslint \
    && rm -rf /var/lib/apt/lists/*

###############################################################################
# (7) Install Docker
###############################################################################
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
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
# (8) Install lsd
###############################################################################
RUN ARCH=$(dpkg --print-architecture) && \
    wget "https://github.com/lsd-rs/lsd/releases/download/v1.1.5/lsd_1.1.5_${ARCH}.deb" -O /tmp/lsd.deb && \
    apt-get update && \
    apt-get install -y /tmp/lsd.deb && \
    rm /tmp/lsd.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

###############################################################################
# (9) Install WebAssembly Binary Toolkit (WABT)
###############################################################################
RUN apt-get update && \
    apt-get install -y wabt && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

###############################################################################
# (10) Install nano syntax highlighting
###############################################################################
RUN git clone https://github.com/scopatz/nanorc.git /tmp/nanorc \
    && mkdir -p /usr/share/nano-syntax \
    && cp -r /tmp/nanorc/* /usr/share/nano-syntax \
    && find /usr/share/nano-syntax -type f -name '*.nanorc' \
         -exec sh -c 'echo "include $1" >> /etc/nanorc' _ {} \; \
    && rm -rf /tmp/nanorc

###############################################################################
# (11) Create the C3 development user
###############################################################################
RUN useradd -m -s /bin/bash ${NONROOT_USER} \
    && echo "${NONROOT_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${NONROOT_USER} \
    && chmod 0440 /etc/sudoers.d/${NONROOT_USER} \
    && groupadd -f docker \
    && usermod -aG docker ${NONROOT_USER}

###############################################################################
# (12) Install C3 Compiler
###############################################################################
RUN mkdir -p ${HOME}/bin && \
    wget https://github.com/c3lang/c3c/releases/latest/download/c3-ubuntu-22.tar.gz -O /tmp/c3.tar.gz && \
    tar -xzf /tmp/c3.tar.gz -C ${HOME}/bin && \
    rm /tmp/c3.tar.gz && \
    chown -R ${NONROOT_USER}:${NONROOT_USER} ${HOME}/bin

###############################################################################
# (13) Set default shell to bash
###############################################################################
SHELL ["/bin/bash", "-c"]

###############################################################################
# (14) Adjust file ownership and create workspace
###############################################################################
WORKDIR /workspace
RUN mkdir -p ${HOME}/.docker && \
    chown -R ${NONROOT_USER}:${NONROOT_USER} /workspace ${HOME} && \
    chown -R ${NONROOT_USER}:docker ${HOME}/.docker

###############################################################################
# (15) Switch to the non-root user
###############################################################################
USER ${NONROOT_USER}

###############################################################################
# (16) Configure shell environment
###############################################################################
RUN cp /etc/skel/.bashrc ${HOME}/.bashrc \
    && cp /etc/skel/.profile ${HOME}/.profile

###############################################################################
# (17) Add shell aliases
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
# (18) Configure nano and editor settings
###############################################################################
RUN echo "include /usr/share/nano-syntax/*.nanorc" >> ${HOME}/.nanorc \
    && echo "export EDITOR=nano" >> ${HOME}/.bash_profile

###############################################################################
# (19) Add C3 compiler to PATH
###############################################################################
RUN echo '' >> ${HOME}/.bashrc && \
    echo '# Add C3 compiler to PATH' >> ${HOME}/.bashrc && \
    echo 'export PATH="$HOME/bin/c3:$PATH"' >> ${HOME}/.bashrc

###############################################################################
# (20) Customize terminal prompt
###############################################################################
ENV TERM=xterm-256color
RUN echo "\
# Colorized PS1 prompt\n\
export PS1=\"\[\e[0;32m\]\u@\h\[\e[m\]:\[\e[0;34m\]\w\[\e[m\]\$ \"\
" >> ${HOME}/.bashrc

###############################################################################
# (21) Fix ownership of config files
###############################################################################
RUN chown ${NONROOT_USER}:${NONROOT_USER} \
    ${HOME}/.bashrc \
    ${HOME}/.profile \
    ${HOME}/.bash_profile \
    ${HOME}/.nanorc \
    ${HOME}/.bash_aliases

###############################################################################
# (22) Set default command
###############################################################################
CMD ["bash", "-i"]
