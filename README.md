# Zimbra Collaboration Suite Docker Containers

## Setup
If you do not have access to the f9teams organization on Docker Hub, @spoon16 in Slack with your Docker Hub username.

`docker login --username <your docker hub username>`

## f9teams/zmc-dev:base
See ./base/Dockerfile

This is the base Docker container that has should allow the successful installation of Zimbra Collaboration Suite.

```
docker pull f9teams/zmc-dev:base
docker run --privileged -i -t f9teams/zmc-dev:base ./resolvconf-setup
```

## f9teams/zmc-dev:build
See ./develop/Dockerfile

This is a Docker container running a recent pull of the develop branch of https://github.com/Zimbra/zm-build

```
docker network create --driver=bridge --subnet=10.0.0.0/24 zmc-bridge
docker pull f9teams/zmc-dev:build
```

Run the following command once your container starts. This is frustratingly the only way I have been able to get a recent build of ZCS working in a container. All forms of automated setup fail and committing a container even with all Zimbra services stopped results in a container that will not start properly, `ldap` fails to come online.

```
docker run --rm --network=zmc-bridge --hostname=zmc-dev.f9teams.engineering --ip 10.0.0.2 -p 443:443 -p 7071:7071 -i -t f9teams/zmc-dev:build bash
> /opt/zimbra/libexec/zmsetup.pl
```
