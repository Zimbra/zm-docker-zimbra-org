FROM ubuntu:16.04

ARG ZM_RELEASE=8.8.0

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y software-properties-common openjdk-8-jdk ant ant-contrib \
                       ruby git maven build-essential wget

RUN cd /tmp/ && git clone https://github.com/Zimbra/zm-build.git && \
    cd zm-build && git checkout origin/develop

# TODO remove
WORKDIR /tmp/zm-build

RUN ./build.pl --build-no=1723 --build-ts=`date +'%Y%m%d%H%M%S'` \
               --build-release=JUDASPRIEST --build-release-no=${ZM_RELEASE} \
               --build-release-candidate=GA --build-type=FOSS \
               --build-thirdparty-server=files.zimbra.com --no-interactive

RUN cp /tmp/BUILDS/*/*/*/zm-build/*.tgz /tmp/zm-build/build.tgz && mkdir zm-${ZM_RELEASE} && \
    tar xzvf build.tgz --strip 1 -C zm-${ZM_RELEASE} && ls -la /tmp/zm-build && \
    rm -rf /tmp/BUILDS

# TODO remove
WORKDIR /tmp/zm-build/zm-${ZM_RELEASE}

RUN ./install.sh

# TODO move packages into /opt/zm-build ?
