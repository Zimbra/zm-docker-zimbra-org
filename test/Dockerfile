FROM f9teams/zmc-dev:build

WORKDIR /opt/zimbra
RUN mkdir /opt/zimbra/.gradle && \
    apt-get install -y gradle && \
    mkdir /opt/zimbra/zm-integ-tests

VOLUME /opt/zimbra/zm-integ-tests

RUN chown -R zimbra:zimbra /opt/zimbra

