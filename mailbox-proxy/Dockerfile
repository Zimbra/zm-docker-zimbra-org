ARG DOCKER_REPO_NS
ARG DOCKER_BUILD_TAG
FROM ${DOCKER_REPO_NS}/zmc-base:${DOCKER_BUILD_TAG}

WORKDIR /tmp
RUN apt-get install -y zimbra-store-base zimbra-store-components
RUN apt-get install -y dnsutils software-properties-common
RUN add-apt-repository ppa:vbernat/haproxy-1.8 && apt-get update && apt-get install -y haproxy

# special post install fixes
RUN rm -f /opt/zimbra/common/sbin/mysqld                                                           # FIXME: mysql.server should not be required with zimbra-store
RUN sed -i -e '/^\(START\|STOP\)_ORDER/ { s/\s\?mysql.server\s\?//; }' /opt/zimbra/bin/zmstorectl  # FIXME: mysql.server should not be required with zimbra-store

RUN mkdir -p /opt/zimbra
WORKDIR /opt/zimbra
COPY common/Zimbra/TaskDispatch.pm common/lib/perl5/Zimbra/TaskDispatch.pm
COPY common/Zimbra/DockerLib.pm common/lib/perl5/Zimbra/DockerLib.pm
COPY mailbox-proxy/healthcheck.py healthcheck.py
COPY mailbox-proxy/entry-point.pl entry-point.pl
COPY mailbox-proxy/mailbox-monitor mailbox-monitor
RUN chmod +x entry-point.pl
RUN chmod +x healthcheck.py
RUN chmod +x mailbox-monitor
RUN perl -c entry-point.pl

ENTRYPOINT ./entry-point.pl
EXPOSE 7072 8080 8443
