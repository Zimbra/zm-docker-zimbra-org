FROM f9teams/zmc-dev:latest

WORKDIR /zimbra
ADD ./* /zimbra/

ENTRYPOINT /zimbra/mailbox-entrypoint.sh

HEALTHCHECK --interval=30s --retries=100 CMD /zimbra/mailbox-healthcheck.sh
