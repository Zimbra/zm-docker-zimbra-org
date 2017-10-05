FROM zimbra/zmc-base

WORKDIR /tmp
RUN apt-get install -y \
   zimbra-mariadb

WORKDIR /opt/zimbra
COPY ./entry-point.pl ./entry-point.pl
RUN chmod +x ./entry-point.pl
COPY ./healthcheck.py ./healthcheck.py
RUN chmod +x ./healthcheck.py

ENTRYPOINT ./entry-point.pl
EXPOSE 5000 7306
