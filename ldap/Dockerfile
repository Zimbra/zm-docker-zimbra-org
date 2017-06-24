FROM f9teams/zmc-base:latest

WORKDIR /tmp
# This is my hack to trick Zimbra into picking up the eventual hostname, instead
# of the current Docker assigned hostname. Zimbra has some goofy rules, example;
# a FQDN must have 2 or more '.'s
COPY ./hostname ./hack/hostname
RUN chmod +x ./hack/hostname

COPY ./ldap/install-ldap ./install-ldap
RUN export PATH=/tmp/hack:$PATH && \
    echo "`hostname -i` `hostname --fqdn`" >> /etc/hosts && \
    cd /tmp/BUILDS/*/*/*/zm-build/zcs-* && \
    ./install.sh -s < /tmp/install-ldap

COPY ./zmc-config ./zmc-config
COPY ./ldap/ldap-config ./ldap-config
RUN cat ./zmc-config ./ldap-config | sed '/^\s*$/d' >> ./config

WORKDIR /opt/zimbra
COPY ./ldap/ldap-entrypoint ./ldap-entrypoint
RUN chmod +x ./ldap-entrypoint

ENTRYPOINT ./ldap-entrypoint
RUN ls -la
EXPOSE 22 25 465 587 110 143 993 995 80 443 8080 8443 7071
