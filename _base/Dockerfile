FROM ubuntu:16.04

RUN apt-get update && \
    apt-get install -y \
    # install basics
    curl \
    gettext \
    python \
    python-pip \
    slay \
    vim \
    wget \
    # install zimbra pre-requisites
    ant \
    ant-contrib \
    build-essential \
    git \
    maven \
    net-tools \
    npm \
    openjdk-8-jdk \
    ruby \
    rsyslog \
    software-properties-common

WORKDIR /opt/zimbra

RUN npm install -g n && \
    n latest && \
    npm install -g junit-merge

# Install flask for healthcheck
RUN pip install --upgrade pip && \
    pip install flask flask_api

RUN groupadd -r zimbra && \
    useradd -r -g zimbra zimbra && \
    chsh -s /bin/bash zimbra && \
    chown zimbra:zimbra /opt/zimbra && \
    usermod -d /opt/zimbra zimbra && \
    # Trick build into skipping resolvconf as docker overrides for DNS
    echo "resolvconf resolvconf/linkify-resolvconf boolean false" | debconf-set-selections

RUN echo "deb [trusted=yes] https://files.zimbra.com/dev-releases/hold/UBUNTU16_64-Zimbra-886-20171023521800-FOSS-261/archives/zimbra-foss    ./ # Zimbra Package Archive (zimbra-foss)"     > /etc/apt/sources.list.d/zimbra-packages.list
RUN echo "deb [trusted=yes] https://files.zimbra.com/dev-releases/hold/UBUNTU16_64-Zimbra-886-20171023521800-FOSS-261/archives/zimbra-zextras ./ # Zimbra Package Archive (zimbra-zextras)" >> /etc/apt/sources.list.d/zimbra-packages.list
RUN echo "deb [arch=amd64]  https://repo.zimbra.com/apt/87 xenial zimbra" > /etc/apt/sources.list.d/zimbra.list

RUN apt-get install -y apt-transport-https
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 9BE6ED79
RUN apt-get update -qq
RUN apt-get install -y zimbra-core

# FIXME - the following should be part of appropriate package
RUN mkdir /opt/zimbra/conf/ca
RUN chown zimbra.zimbra /opt/zimbra/conf/ca
RUN [ "sed", "-i", "-e", "s/^\\(my .LOGHOST\\)=\\(qx.*\\);/\\1=(!@ARGV || $ARGV[0] eq 'remote') ? \\2 : '';/", "-e", "s/destination mail { /destination mail \\\\{ /", "/opt/zimbra/libexec/zmsyslogsetup" ]
