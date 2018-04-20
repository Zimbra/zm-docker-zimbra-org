ARG DOCKER_REPO_NS_BASE
ARG DOCKER_BUILD_TAG
FROM ${DOCKER_REPO_NS_BASE}:${DOCKER_BUILD_TAG}

WORKDIR /tmp
RUN apt-get install -y zimbra-mariadb

#FIXME - manual default configs and permissions should not be required outside of apt-get install
RUN [ "mkdir", "-p", "/opt/zimbra/index", "/opt/zimbra/store", "/opt/zimbra/mailboxd" ]
RUN [ "chown", "-R", "zimbra.zimbra", "/opt/zimbra" ]
RUN ["/opt/zimbra/libexec/zmfixperms"]

WORKDIR /opt/zimbra
COPY common/Zimbra/TaskDispatch.pm common/lib/perl5/Zimbra/TaskDispatch.pm
COPY common/Zimbra/DockerLib.pm common/lib/perl5/Zimbra/DockerLib.pm
COPY mysql/healthcheck.py healthcheck.py
COPY mysql/entry-point.pl entry-point.pl
RUN chmod +x entry-point.pl
RUN chmod +x healthcheck.py
RUN perl -c entry-point.pl

ENTRYPOINT ./entry-point.pl
EXPOSE 5000 7306
