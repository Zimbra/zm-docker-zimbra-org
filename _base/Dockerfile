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

RUN mkdir -p /zimbra/release && \
    curl 'https://files.zimbra.com/dev-releases/hold/UBUNTU16_64-shri314-886-20171005050732-FOSS-417/zcs-8.8.6_beta_417.UBUNTU16_64.20171005050732.tgz' \
    -H 'Accept-Encoding: gzip, deflate, br' \
    -H 'Accept-Language: en-US,en;q=0.8' \
    -H 'Upgrade-Insecure-Requests: 1' \
    -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.115 Safari/537.36' \
    -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8' \
    -H 'Referer: https://www.zimbra.com/downloads/zimbra-collaboration-open-source/' \
    -H 'Connection: keep-alive' \
    --compressed -o /tmp/release-zimbra-8.tgz && \
    tar xzvf /tmp/release-zimbra-8.tgz -C /zimbra/release --strip-components=1 && \
    rm /tmp/release-zimbra-8.tgz && \
    sed -i.bak 's/checkRequired/# checkRequired/' /zimbra/release/install.sh

RUN echo "deb [trusted=yes] https://files.zimbra.com/dev-releases/hold/UBUNTU16_64-shri314-886-20171005050732-FOSS-417/archives/zimbra-foss    ./ # Zimbra Package Archive (zimbra-foss)"     > /etc/apt/sources.list.d/zimbra-packages.list
RUN echo "deb [trusted=yes] https://files.zimbra.com/dev-releases/hold/UBUNTU16_64-shri314-886-20171005050732-FOSS-417/archives/zimbra-zextras ./ # Zimbra Package Archive (zimbra-zextras)" >> /etc/apt/sources.list.d/zimbra-packages.list
RUN echo "deb [arch=amd64]  https://repo.zimbra.com/apt/87 xenial zimbra" > /etc/apt/sources.list.d/zimbra.list
RUN echo "deb [trusted=yes] file:///zimbra/release/packages ./"           > /etc/apt/sources.list.d/local.list
RUN apt-get install -y apt-transport-https
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 9BE6ED79
RUN apt-get update -qq
RUN apt-get install -y zimbra-core

# FIXME - the following should be part of appropriate package
RUN mkdir /opt/zimbra/conf/ca
RUN chown zimbra.zimbra /opt/zimbra/conf/ca
RUN [ "sed", "-i", "-e", "s/^\\(my .LOGHOST\\)=\\(qx.*\\);/\\1=(!@ARGV || $ARGV[0] eq 'remote') ? \\2 : '';/", "-e", "s/destination mail { /destination mail \\\\{ /", "/opt/zimbra/libexec/zmsyslogsetup" ]
