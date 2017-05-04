# Running ImapTest against your Zimbra

## Setup
```
docker network create --driver=bridge --subnet=10.0.0.0/24 zmc-bridge
docker build --network=zmc-bridge  -t f9teams/zmc-dev:imaptest .
docker run --network=zmc-bridge --hostname=zmc-dev.f9teams.engineering --ip 10.0.0.2 -p 443:443 -p 7071:7071 -u imaptest -i -t f9teams/zmc-dev:imaptest bash
```

## Run a test
cd into the /opt/imaptest/imaptest-..../src/

```
imaptest user=imaptest@zmc-dev.f9teams.engineering \
         pass=imaptest \
         port=14300 \
         test=tests/
```
