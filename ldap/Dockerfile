FROM zimbra/zmc-base

WORKDIR /tmp
RUN apt-get install -y \
   zimbra-ldap

WORKDIR /opt/zimbra
COPY ./entry-point.pl ./entry-point.pl
RUN chmod +x ./entry-point.pl
RUN mv /zimbra/healthcheck.py ./healthcheck.py
RUN chmod +x ./healthcheck.py

ENTRYPOINT ./entry-point.pl
EXPOSE 389 5000
