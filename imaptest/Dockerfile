FROM f9teams/zmc-dev:develop

RUN apt-get update && \
    apt-get install -y libssl-dev stunnel

RUN groupadd -r imaptest && \
    useradd -r -g imaptest imaptest && \
    chsh -s /bin/bash imaptest && \
    mkdir /opt/imaptest && \
    chown imaptest:imaptest /opt/imaptest && \
    usermod -d /opt/imaptest imaptest

WORKDIR /opt/stunnel
COPY ./imapssl.conf ./imapssl.conf
RUN stunnel imapssl.conf

USER zimbra
RUN /opt/zimbra/bin/zmcontrol start; exit 0
RUN zmprov ca imaptest@zmc-dev.f9teams.engineering imaptest

USER imaptest
WORKDIR /opt/imaptest

RUN curl https://dovecot.org/nightly/dovecot-latest.tar.gz > dovecot-latest.tar.gz
RUN tar -xzf dovecot-latest.tar.gz
RUN cd dovecot-* && ./configure && make

WORKDIR /opt/imaptest
RUN curl https://dovecot.org/nightly/imaptest/imaptest-latest.tar.gz > imaptest-latest.tar.gz
RUN tar -xzf imaptest-latest.tar.gz
RUN cd imaptest-* && ./configure --with-dovecot=$(ls -d ../dovecot-*/) && make
