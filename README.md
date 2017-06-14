# Zimbra Collaboration Suite Docker Containers

## Setup
If you do not have access to the f9teams organization on Docker Hub, @spoon16 in Slack with your Docker Hub username.

`docker login --username <your docker hub username>`

These containers are _large_ (~105GB) :cry:.

### Docker Machine with VirtualBox
```
brew install docker docker-compose docker-machine && \
brew cask install virtualbox
```

I've had the best luck in terms of Docker responsiveness for macOS using Docker Machine with VirtualBox.

To configured a VirtualBox Docker Machine run.

```
docker-machine create --virtualbox-disk-size 180000 --virtualbox-memory 8096 --virtualbox-cpu-count 4 --driver virtualbox default
```

Add this to your shell profile.

```
eval "$(docker-machine env default)"
```

`docker`, `docker-compose`, etc... should all work now.

### Docker Native
```
brew cask install docker && \
brew install docker-compose
```

I've had difficulty with Docker Native responsiveness for macOS. Using `docker-machine` with VirtualBox seems much consistent.

To get things working at all you'll need to increase the number of cores and the amount of memory that Docker can utilize on your macOS.

Use `qemu` (`brew install qemu`) to increase the available size from 64G to 128G. This will effectively hard reset your local docker state (all containers gone).

```
cd ~/Library/Containers/com.docker.docker/Data/com.docker.driver.amd64-linux/
rm Docker.qcow2
qemu-img create -f qcow2 ./Docker.qcow2 128G
```

## Starting a Zimbra Cluster

```
docker-compose up
```

## Service Containers

### f9teams/zmc-ldap

### f9teams/zmc-mta

### f9teams/zmc-mailbox

### f9teams/zmc-proxy

## Other Containers

### f9teams/zmc-base
This is the base Docker container from which all other Zimbra containers are derived. Allows the successful build, install, and configure of Zimbra Collaboration Suite.

See [zmc-base README.md](./base/README.md)

### f9teams/zmc-build
This is a Docker container that will pull and build the master branch of https://github.com/f9teams/zm-build

See [zmc-build README.md](./build/README.md)
