FROM python:3.8-alpine

ENV DEFAULT_TZ=Europe/Berlin \
    LANG=de_DE.UTF-8 \
    LANGUAGE=de_DE.UTF-8 \
    LC_ALL=de_DE.UTF-8

COPY python.pkgs /usr/local/share/pip/compile.pkgs
RUN set -eux; \
    # Install permanent system packages
    apk --update add --no-cache \
        coreutils \
        curl \
        wget \
        bash \
        zip \
        git \
        jq \
        openssl \
        openssh \
        sshpass \
        krb5 \
        krb5-dev \
        #openjdk11-jre-headless \
    ; \
    # Install build-dependent system packages
    apk add --no-cache --virtual .build-deps \
        gcc \
        make \
        musl-dev \
        libffi-dev \
        libxml2-dev \
        libxslt-dev \
        openssl-dev \
        gnupg \
        tzdata \
    ; \
    \
    # Set timezone
    cp /usr/share/zoneinfo/${DEFAULT_TZ} /etc/localtime; \
    echo "${DEFAULT_TZ}" >/etc/timezone; \
    \
    # Install Ansible, Azure, AWS and DNS python packages
    pip install --no-cache-dir pip-tools; \
    pip-compile -qo /usr/local/share/pip/install.pkgs /usr/local/share/pip/compile.pkgs; \
    pip install --no-cache-dir -r /usr/local/share/pip/install.pkgs; \
    \
    # Install HashiCorp binaries
    mkdir -p /usr/local/share/hashicorp; \
    wget -qO /usr/local/share/hashicorp/install.sh https://raw.github.com/zeiss-digital-innovation/install-hashicorp-binaries/master/install-hashicorp.sh; \
    chmod +x /usr/local/share/hashicorp/install.sh; \
    /usr/local/share/hashicorp/install.sh packer terraform; \
    \
    # Install ACME client
    git clone --depth 1 https://github.com/dehydrated-io/dehydrated.git /usr/local/etc/dehydrated; \
    ln -s /usr/local/etc/dehydrated/dehydrated /usr/local/bin/dehydrated; \
    mkdir -p /usr/local/etc/dehydrated/hooks; \
    wget -qO /usr/local/etc/dehydrated/hooks/lexicon.sh https://raw.githubusercontent.com/AnalogJ/lexicon/master/examples/dehydrated.default.sh; \
    \
    apk del .build-deps

COPY config /tmp/config
RUN set -eux; \
    # Install Starship shell prompt
    if [ "$(uname -m)" = "x86_64" -a "$(getconf LONG_BIT)" = "64" ]; then \
        curl -Os https://starship.rs/install.sh; \
        chmod +x ./install.sh; \
        ./install.sh -V -f; \
        rm install.sh; \
        mkdir -p ~/.config; \
        mv /tmp/config/starship.toml ~/.config/starship.toml; \
    fi; \
    mv /tmp/config/.bashrc ~/.bashrc; \
    \
    # Install vim editor and nerd fonts
    apk --update add --no-cache \
        fontconfig \
        vim \
    ; \
    apk --update add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/v3.13/community \
        font-noto-emoji \
    ; \
    wget -q https://github.com/ryanoasis/nerd-fonts/releases/latest/download/SourceCodePro.zip; \
    mkdir -p /usr/share/fonts/nerd; \
    unzip -d /usr/share/fonts/nerd SourceCodePro.zip; \
    rm SourceCodePro.zip; \
    find /usr/share/fonts/nerd/ -type f -name "*Windows Compatible.ttf" -exec rm -f {} \;; \
    mv /tmp/config/nerd-emoji-font.conf /usr/share/fontconfig/conf.avail/05-nerd-emoji.conf; \
    ln -s /usr/share/fontconfig/conf.avail/05-nerd-emoji.conf /etc/fonts/conf.d/05-nerd-emoji.conf; \
    fc-cache -vf; \
    mv /tmp/config/.vimrc ~/.vimrc; \
    # vim -c 'PlugInstall' -c 'qa!'; \
    rm -rf /tmp/config

WORKDIR /srv

CMD [ "/bin/sh","-c","sleep infinity & wait" ]
