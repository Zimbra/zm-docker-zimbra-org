FROM ubuntu:16.04

RUN apt-get update && \
  apt-get install -y \
# install basics
  vim \
  wget \
  curl \
  gettext \
  slay \
  python \
  python-pip \
# install zimbra pre-requisites
  ant \
  ant-contrib \
  build-essential \
  git \
  maven \
  openjdk-8-jdk \
  ruby \
  net-tools \
  rsyslog \
  software-properties-common

WORKDIR /tmp/zimbra
COPY ./rsyslog-fix ./rsyslog-fix
RUN chmod +x ./rsyslog-fix && \
    ./rsyslog-fix

COPY ./resolvconf-setup ./resolvconf-setup
RUN chmod +x ./resolvconf-setup
