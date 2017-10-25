FROM ubuntu:16.04

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

################# INSTALLING ZIMBRA CORE #################
RUN useradd -d /opt/zimra -s /bin/bash -r zimbra

# Trick build into skipping resolvconf as docker overrides for DNS
RUN echo "resolvconf resolvconf/linkify-resolvconf boolean false" | debconf-set-selections

# Access to package repository
RUN echo "deb [trusted=yes] https://files.zimbra.com/dev-releases/hold/UBUNTU16_64-Zimbra-886-20171023521800-FOSS-261/archives/zimbra-foss    ./ # Zimbra Package Archive (zimbra-foss)"     > /etc/apt/sources.list.d/zimbra-packages.list
RUN echo "deb [trusted=yes] https://files.zimbra.com/dev-releases/hold/UBUNTU16_64-Zimbra-886-20171023521800-FOSS-261/archives/zimbra-zextras ./ # Zimbra Package Archive (zimbra-zextras)" >> /etc/apt/sources.list.d/zimbra-packages.list
RUN echo "deb [arch=amd64]  https://repo.zimbra.com/apt/87 xenial zimbra" > /etc/apt/sources.list.d/zimbra.list

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 9BE6ED79
RUN apt-get update
RUN apt-get install -y rsyslog
RUN apt-get install -y zimbra-core

# FIXME - the following should be part of appropriate package
RUN mkdir /opt/zimbra/conf/ca
RUN chown zimbra.zimbra /opt/zimbra/conf/ca
RUN [ "sed", "-i", "-e", "s/^\\(my .LOGHOST\\)=\\(qx.*\\);/\\1=(!@ARGV || $ARGV[0] eq 'remote') ? \\2 : '';/", "-e", "s/destination mail { /destination mail \\\\{ /", "/opt/zimbra/libexec/zmsyslogsetup" ]

WORKDIR /opt/zimbra
