FROM zimbra/zmc-base

WORKDIR /tmp
RUN apt-get install -y \
   zimbra-store \
   zimbra-imapd \
   zimbra-chat \
   zimbra-drive

RUN rm -f /opt/zimbra/common/sbin/mysqld                                                           # FIXME: mysql.server should not be required with zimbra-store
RUN sed -i -e '/^\(START\|STOP\)_ORDER/ { s/\s\?mysql.server\s\?//; }' /opt/zimbra/bin/zmstorectl  # FIXME: mysql.server should not be required with zimbra-store

WORKDIR /opt/zimbra
COPY ./entry-point.pl ./entry-point.pl
RUN chmod +x ./entry-point.pl
RUN mv /zimbra/healthcheck.py ./healthcheck.py
RUN chmod +x ./healthcheck.py

ENTRYPOINT ./entry-point.pl
EXPOSE 110 143 993 995 80 443 8080 8443 7071
