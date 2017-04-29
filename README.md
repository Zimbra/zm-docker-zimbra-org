# Zimbra Collaboration Suite Docker Containers

## Setup
If you do not have access to the f9teams organization on Docker Hub, @spoon16 in Slack with your Docker Hub username.

`docker login --username <your docker hub username>`

## f9teams/zmc-dev:base
`docker pull f9teams/zmc-dev:base`

This is the base Docker container that has should allow the successful installation of Zimbra Collaboration Suite.

See ./base/Dockerfile

## f9teams/zmc-dev:develop
`docker pull f9teams/zmc-dev:develop`

This is a Docker container running a recent pull of the develop branch of https://github.com/Zimbra/zm-build
