FROM ubuntu:16.04

ARG ZM_RELEASE=8.8.0

RUN apt-get update && apt-get upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common openjdk-8-jdk ant ant-contrib \
                                                      ruby git maven build-essential wget

# Build ZCS and prep for installation in child containers
RUN cd /tmp/ && git clone https://github.com/Zimbra/zm-build.git && \
    cd zm-build && git checkout origin/develop && \
    ./build.pl --build-no=1723 --build-ts=`date +'%Y%m%d%H%M%S'` \
               --build-release=JUDASPRIEST --build-release-no=${ZM_RELEASE} \
               --build-release-candidate=GA --build-type=FOSS \
               --build-thirdparty-server=files.zimbra.com --no-interactive && \
    mkdir -p /opt/zimbra-build && cd /opt/zimbra-build && \
    tar xzvf /tmp/BUILDS/*/*/*/zm-build/*.tgz --strip 1 && \
    rm -rf /tmp/BUILDS

# Docker uses /etc/resolv.conf to manage DNS - trick installation process into
# thinking that it is already installed
RUN echo "resolvconf resolvconf/linkify-resolvconf boolean false" | debconf-set-selections
