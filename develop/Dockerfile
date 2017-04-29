FROM f9teams/zmc-dev:base

RUN groupadd -r zimbra && \
    useradd -r -g zimbra zimbra && \
    chsh -s /bin/bash zimbra && \
    mkdir /opt/zimbra && \
    chown zimbra:zimbra /opt/zimbra && \
    usermod -d /opt/zimbra zimbra

WORKDIR /tmp
RUN git clone https://github.com/Zimbra/zm-build.git
WORKDIR /tmp/zm-build
RUN git checkout develop
COPY ./config.build ./config.build
RUN ./build.pl

WORKDIR /opt/zimbra
