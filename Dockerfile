ARG BASE_IMAGE="ubuntu"
ARG TAG="latest"
FROM ${BASE_IMAGE}:${TAG}

# Install prerequisites
RUN apt-get update \
    && DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        cabextract \
        git \
        gnupg \
        gosu \
        gpg-agent \
        locales \
        sudo \
        tzdata \
        unzip \
        wget \
        winbind \
        xvfb \
    && rm -rf /var/lib/apt/lists/*

# Install wine (optionally removing 64-bit wine files saves ~600MB in image size)
ARG WINE_BRANCH="stable"
ARG DEL_64BIT=false
RUN wget -nv -O- https://dl.winehq.org/wine-builds/winehq.key | APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add - \
    && echo "deb https://dl.winehq.org/wine-builds/ubuntu/ $(grep VERSION_CODENAME= /etc/os-release | cut -d= -f2) main" >> /etc/apt/sources.list \
    && dpkg --add-architecture i386 \
    && apt-get update \
    && DEBIAN_FRONTEND="noninteractive" apt-get install -y --install-recommends winehq-${WINE_BRANCH} \
    && rm -rf /var/lib/apt/lists/* \
    && if [ "$DEL_64BIT" = "true" ]; then echo "Removing 64bit wine files files..." && rm -rf /opt/wine-stable/lib64; fi

# Install winetricks (optionally)
ARG WINETRICKS=true
RUN if [ "$WINETRICKS" = "true" ]; then \
    wget -nv -O /usr/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
    && chmod +x /usr/bin/winetricks; fi

# Download mono installer (skip gecko!)
COPY download_gecko_and_mono.sh /root/download_gecko_and_mono.sh
RUN chmod +x /root/download_gecko_and_mono.sh \
    && /root/download_gecko_and_mono.sh "$(wine --version | sed -E 's/^wine-//')"

# Configure locale for unicode
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8

COPY entrypoint.sh /usr/bin/entrypoint
ENTRYPOINT ["/usr/bin/entrypoint"]
