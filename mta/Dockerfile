FROM zimbra/zmc-base

WORKDIR /tmp
RUN apt-get install -y \
   zimbra-mta
RUN sed -i -e 's/\(^[$]myhostname = \)\(.\)@@/\1\2localhost\2; #/' /opt/zimbra/conf/amavisd.conf.in    # FIXME: AMAVISD refuses to start if myhostname does not have [.] in its FQDN

WORKDIR /opt/zimbra
COPY ./entry-point.pl ./entry-point.pl
RUN chmod +x ./entry-point.pl
RUN mv /zimbra/healthcheck.py ./healthcheck.py
RUN chmod +x ./healthcheck.py

ENTRYPOINT ./entry-point.pl
EXPOSE 25 465 587
