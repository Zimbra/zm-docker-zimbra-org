FROM zimbra/zmc-base

WORKDIR /tmp
RUN apt-get install -y \
   zimbra-proxy

WORKDIR /opt/zimbra
COPY ./entry-point.pl ./entry-point.pl
RUN chmod +x ./entry-point.pl
RUN mv /zimbra/healthcheck.py ./healthcheck.py
RUN chmod +x ./healthcheck.py

ENTRYPOINT ./entry-point.pl
EXPOSE 25 465 587 110 143 993 995 80 443 8080 8443 7071
