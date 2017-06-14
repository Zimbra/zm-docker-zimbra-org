FROM f9teams/zmc-dev:latest

WORKDIR /zimbra
ADD ./* /zimbra/

ENTRYPOINT /zimbra/ldap-entrypoint.sh

EXPOSE 389
HEALTHCHECK --interval=30s --retries=100 CMD /zimbra/ldap-healthcheck.sh
