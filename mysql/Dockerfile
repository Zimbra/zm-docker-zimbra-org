FROM zimbra/zmc-base

WORKDIR /tmp
RUN apt-get install -y zimbra-mariadb

WORKDIR /opt/zimbra
COPY common/Zimbra/DockerLib.pm common/lib/perl5/Zimbra/DockerLib.pm
COPY mysql/healthcheck.py healthcheck.py
COPY mysql/entry-point.pl entry-point.pl
RUN chmod +x entry-point.pl
RUN chmod +x healthcheck.py

ENTRYPOINT ./entry-point.pl
EXPOSE 5000 7306
