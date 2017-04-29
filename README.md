# Zimbra Collaboration Suite Docker Containers

## Setup
If you do not have access to the f9teams organization on Docker Hub, @spoon16 in Slack with your Docker Hub username.

`docker login --username <your docker hub username>`

## f9teams/zmc-dev:base
```
docker pull f9teams/zmc-dev:base
docker run --privileged -i -t f9teams/zmc-dev:base ./resolvconf-setup
```

This is the base Docker container that has should allow the successful installation of Zimbra Collaboration Suite.

See ./base/Dockerfile

## f9teams/zmc-dev:develop
```
docker network create --driver=bridge --subnet=10.0.0.0/24 zmc-bridge
docker pull f9teams/zmc-dev:develop
docker run --network=zmc-bridge --hostname=zmc-dev.f9teams.engineering --ip 10.0.0.2 -p 443:443 -p 7071:7071 -i -t f9teams/zmc-dev:develop bash
```

This is a Docker container running a recent pull of the develop branch of https://github.com/Zimbra/zm-build
