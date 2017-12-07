FROM ubuntu:16.04

# Install Basic Packages
RUN apt-get update && \
    apt-get install -y \
    ant \
    ant-contrib \
    build-essential \
    curl \
    dnsmasq \
    dnsutils \
    gettext \
    git \
    git-flow \
    libdigest-hmac-perl \
    linux-tools-common \
    maven \
    netcat \
    net-tools \
    npm \
    openjdk-8-jdk \
    python \
    python-pip \
    ruby \
    rsyslog \
    software-properties-common \
    vim \
    wget && \
    apt-get install -y man psutils psmisc ruby-dev gcc && \
    apt-get clean

WORKDIR /tmp
# Install STAF to /usr/local/staf
# Unpack the QA soapvalidator tests to /opt/qa/soapvalidator
# Unpack the QA genesis tests to /opt/qa/genesis
# Add the STAF libraries to the END of the list of places where libraries are searched
# Some of the libraries included with STAF are wonky and will bork normal commands
# if they are loaded first.
RUN curl -L -O http://downloads.sourceforge.net/project/staf/staf/V3.4.26/STAF3426-setup-linux-amd64-NoJVM.bin
RUN curl -k -L -o soapvalidator.tar.gz https://docker.zimbra.com.s3.amazonaws.com/assets/soapvalidator-20171120.tar.gz
RUN curl -k -L -o genesis.tar https://docker.zimbra.com.s3.amazonaws.com/assets/genesis-20171130.tar
RUN mkdir -p /opt/qa && \
    mkdir -p /opt/qa/logs/soap-harness && \
    mkdir -p /opt/qa/logs/genesis && \
    tar xzf /tmp/soapvalidator.tar.gz -C /opt/qa/ && \
    tar xf /tmp/genesis.tar -C /opt/qa/ && \
    sync && \
    chmod +x /tmp/STAF3426-setup-linux-amd64-NoJVM.bin && \
    /tmp/STAF3426-setup-linux-amd64-NoJVM.bin -i silent \
       -DACCEPT_LICENSE=1 \
       -DCHOSEN_INSTALL_SET=Custom \
       -DCHOSEN_INSTALL_FEATURE_LIST=STAF,ExtSvcs,Langs,Codepage && \
    rm /tmp/STAF3426-setup-linux-amd64-NoJVM.bin && \
    rm /tmp/soapvalidator.tar.gz && \
    rm /tmp/genesis.tar && \
    echo /usr/local/staf/lib > /etc/ld.so.conf.d/zzz-staf.conf && \
    ldconfig && \
    gpg --keyserver keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 && \
    curl -sSL https://get.rvm.io | bash -s stable && \
    /bin/bash -c 'source /etc/profile.d/rvm.sh && rvm install 2.0.0 --with-zlib-directory=/usr/local/rvm/usr --with-openssl-directory=/usr/local/rvm/usr' && \
    /bin/bash -c 'source /etc/profile.d/rvm.sh && gem install soap4r-spox log4r net-ldap json httpclient parseconfig' && \
    /bin/bash -c 'source /etc/profile.d/rvm.sh && rvm cleanup all' && \
    apt-get clean && \
    curl -o /root/s3curl.pl  https://raw.githubusercontent.com/rtdp/s3curl/master/s3curl.pl && \
    chmod +x /root/s3curl.pl

# ************************************************************************
# The following is required for Genesis tests to be run.
# 1. Disable setting that prevents users from writing to current terminal device
# 2. Symlink in /bin/env (some genesis tests expect it to be there)
# 3. Add STAF commands to PATH
# ************************************************************************
RUN sed -i.bak 's/^mesg/# mesg/' /root/.profile && \
    ln -s /usr/bin/env /bin/env && \
    echo 'PATH=/usr/local/staf/bin:$PATH' >> /root/.bashrc


RUN mkdir /zimbra
COPY ./test/init /zimbra/init
COPY ./test/init-common /zimbra/init-common
RUN chmod +x /zimbra/init

