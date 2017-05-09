# Running ImapTest against your Zimbra

## Setup
Setup your test ZCS instance
```
docker network create --driver=bridge --subnet=10.0.0.0/24 zmc-bridge
docker run --network=zmc-bridge --hostname=zmc-dev.f9teams.engineering --ip 10.0.0.2 -p 443:443 -p 7071:7071 -i -u root --name zcs -t f9teams/zmc-dev:build bash
```
Then some manual steps:
```
/opt/zimbra/libexec/zmsetup.pl -c /tmp/install-config
su zimbra
zmprov ca imaptest@zmc-dev.f9teams.engineering imaptest
exit
```

## Run a ImapTest
Setup your ImapTest container
```
docker build -t f9teams/zmc-dev:imaptest .
docker run --network=zmc-bridge -u root --name imaptest -t -t \
   f9teams/zmc-dev:imaptest bash
```
Manual steps to run a test
```
cd /opt/stunnel
stunnel imapssl.conf

su imaptest
cd ~/imaptest-*/src

./imaptest user=imaptest@zmc-dev.f9teams.engineering \
         pass=imaptest \
         port=14300 \
         test=tests/
```
