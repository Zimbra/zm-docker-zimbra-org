FROM circleci/build-image:latest

RUN apt-get update
RUN apt-get install -y ant-contrib

USER ubuntu
WORKDIR /home/ubuntu

RUN git clone https://github.com/Zimbra/zm-timezones.git \
    -b develop --single-branch
