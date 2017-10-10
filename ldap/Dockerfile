FROM zimbra/zmc-base

WORKDIR /tmp
RUN apt-get install -y zimbra-ldap

WORKDIR /opt/zimbra
COPY common/Zimbra/DockerLib.pm common/lib/perl5/Zimbra/DockerLib.pm
COPY common/healthcheck.py healthcheck.py
COPY ldap/entry-point.pl entry-point.pl
RUN chmod +x entry-point.pl
RUN chmod +x healthcheck.py

ENTRYPOINT ./entry-point.pl
EXPOSE 389 5000
