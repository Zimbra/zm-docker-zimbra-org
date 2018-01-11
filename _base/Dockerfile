FROM ubuntu:16.04

ARG PACKAGE_CNF
ARG PACKAGE_KEY

ENV DEBIAN_FRONTEND=noninteractive

################# INSTALLING BASICS #################
RUN apt-get update
RUN apt-get dist-upgrade -y
RUN apt-get autoremove -y
RUN apt-get install -y apt-transport-https
RUN apt-get install -y apt-utils

################# INSTALLING MISC UTILS #################
RUN apt-get install -y python-flask
RUN apt-get install -y python-flask-api
RUN apt-get install -y rsync
RUN apt-get install -y curl
RUN apt-get install -y wget
RUN apt-get install -y vim
RUN apt-get install -y openssh-server
RUN apt-get install -y man
RUN apt-get install -y psmisc
RUN apt-get install -y bzip2

# ************************************************************************
# Set tzdata info to UTC (Etc/UTC) for image.
# Runtime will reconfigure to match what is in environment
# ************************************************************************
RUN echo "tzdata tzdata/Areas select Etc" > /tmp/tzdata.txt && \
    echo "tzdata tzdata/Zones/Etc select UTC" >> /tmp/tzdata.txt && \
    export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && \
    debconf-set-selections /tmp/tzdata.txt && \
    apt-get install -y tzdata && \
    apt-get clean

# ************************************************************************
# The following is required for Genesis tests to be run.
# 1. Disable setting that prevents users from writing to current terminal device
# 2. Symlink in /bin/env (some genesis tests expect it to be there)
# ************************************************************************
RUN sed -i.bak 's/^mesg/# mesg/' /root/.profile && \
    ln -s /usr/bin/env /bin/env && \
    echo 'PATH=/usr/local/staf/bin/:$PATH' >> /root/.bashrc

# ************************************************************************
# Install STAF to /usr/local/staf
#
# Add the STAF libraries to the END of the list of places where libraries are searched
# Some of the libraries included with STAF are wonky and will bork normal commands
# if they are loaded first.
# ************************************************************************
RUN apt-get install -y openjdk-8-jdk
RUN apt-get install -y unzip
RUN curl -L -o /tmp/staf-setup.bin 'http://downloads.sourceforge.net/project/staf/staf/V3.4.26/STAF3426-setup-linux-amd64-NoJVM.bin' && \
    chmod +x /tmp/staf-setup.bin && \
    /tmp/staf-setup.bin -i silent \
       -DACCEPT_LICENSE=1 \
       -DCHOSEN_INSTALL_SET=Custom \
       -DCHOSEN_INSTALL_FEATURE_LIST=STAF,ExtSvcs,Langs,Codepage && \
    rm /tmp/staf-setup.bin && \
    echo /usr/local/staf/lib > /etc/ld.so.conf.d/zzz-staf.conf && \
    ldconfig

################# INSTALLING ZIMBRA CORE #################
RUN useradd -d /opt/zimbra -s /bin/bash -r zimbra

# Trick build into skipping resolvconf as docker overrides for DNS
RUN echo "resolvconf resolvconf/linkify-resolvconf boolean false" | debconf-set-selections

# Access to package repository
COPY $PACKAGE_CNF /etc/apt/sources.list.d/zimbra.list
COPY $PACKAGE_KEY /tmp/key.txt
COPY ./BUILDS/latest /build
RUN ls -AFlh /build/archives/zimbra-foss/u16

RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys `cat /tmp/key.txt | head` && rm -f /tmp/key.txt
RUN apt-get update
RUN apt-get install -y rsyslog
RUN apt-get install -y zimbra-core

# FIXME - the following should be part of appropriate package
RUN mkdir /opt/zimbra/conf/ca
RUN chown zimbra.zimbra /opt/zimbra/conf/ca
RUN [ "sed", "-i", "-e", "s/^\\(my .LOGHOST\\)=\\(qx.*\\);/\\1=(!@ARGV || $ARGV[0] eq 'remote') ? \\2 : '';/", "-e", "s/destination mail { /destination mail \\\\{ /", "/opt/zimbra/libexec/zmsyslogsetup" ]

WORKDIR /opt/zimbra
