FROM zimbra/zmc-base

WORKDIR /tmp
RUN apt-get install -y zimbra-mta

# special post install fixes
RUN sed -i -e 's/\(^[$]myhostname = \)\(.\)@@/\1\2localhost\2; #/' /opt/zimbra/conf/amavisd.conf.in    # FIXME: AMAVISD refuses to start if myhostname does not have [.] in its FQDN

WORKDIR /opt/zimbra
COPY common/Zimbra/TaskDispatch.pm common/lib/perl5/Zimbra/TaskDispatch.pm
COPY common/Zimbra/DockerLib.pm common/lib/perl5/Zimbra/DockerLib.pm
COPY common/healthcheck.py healthcheck.py
COPY mta/entry-point.pl entry-point.pl
RUN chmod +x entry-point.pl
RUN chmod +x healthcheck.py
RUN perl -c entry-point.pl

ENTRYPOINT ./entry-point.pl
EXPOSE 25 465 587
