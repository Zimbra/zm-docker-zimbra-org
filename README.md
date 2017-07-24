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
Minimum config is 3 cpus and 5000 MB of RAM. Otherwise services won't start.

```
docker-machine create --virtualbox-disk-size 180000 --virtualbox-memory 8096 --virtualbox-cpu-count 4 --driver virtualbox default
```

Add this to your shell profile.

```
eval "$(docker-machine env default)"
```

`docker`, `docker-compose`, etc... should all work now.

### Note re: Port Mapping
When using `docker-machine` the ports you map from the docker container using `-p` or configured in the `ports` section of your `docker-compose.yml` will not be bound to localhost. They will be bound to the port returned by `docker-machine ip`. So the mailbox will be exposed on https://192.168.99.100:9443/.

### Docker Native (This will be flakey)

```
brew cask install docker && \
brew install docker-compose
```

I've had difficulty with Docker Native responsiveness for macOS. Using `docker-machine` with VirtualBox seems much consistent.

To get things working at all you'll need to increase the number of cores to at least 3
and the amount of memory to at least 5G that Docker can utilize on your macOS.

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

This will take forever. Health checks for each container will be on `http://10.0.0.x:9000/`

The web UI should load (after clicking through an SSL warning) on `https://10.0.0.4:9443`

## Service Containers

### f9teams/zmc-ldap

### f9teams/zmc-mailbox

### f9teams/zmc-mysql

Runs on `10.0.0.10` port `7306`. Password for root and zimbra are `f9teams`

Why this was hard. Starting with a baseline config of `zm-store`

#### DB passwords are generated at install
```
su -c '/opt/zimbra/bin/zmmypasswd f9teams' zimbra
 su -c '/opt/zimbra/bin/zmmypasswd --root f9teams' zimbra
```

#### DB is configured to lock out remote connections
This happens in two ways: mariadb doesn't bind to anything except localhost, and the DB schema itself is locked.

```
# remove the entry that only lets mysql listen on localhost. Yes this is gross.
 sed -i -e '/bind-address/d' /opt/zimbra/conf/my.cnf
```

Next fix the schema
```
/opt/zimbra/bin/mysql -u root --password=f9teams -e 'grant all privileges on *.* to zimbra;'
su -c '/opt/zimbra/bin/zmcontrol restart' zimbra
```

#### Tell the mailbox server where to find mysql
```
su -c "/opt/zimbra/bin/zmlocalconfig -e mysql_bind_address=zmc-mysql.f9teams.engineering mysql_port=7306" zimbra
```

#### `zm-store` insists on running a mailbox server

This mailbox server runs and registers in LDAP, which makes it part of the mailbox pool. We don't want this.

Shut off the mysql mailbox server and remove it from the pool
```
su -c '/opt/zimbra/bin/zmprov deleteServer zmc-mysql.f9teams.engineering' zimbra
```

From the mailbox server, move the admin account to be hosted there
```
su -c 'zmprov ma admin zimbraMailHost zmc-mailbox.f9teams.engineering' zimbra
```

### f9teams/zmc-mta

### f9teams/zmc-proxy

## Other Containers

### f9teams/zmc-base
This is the base Docker container from which all other Zimbra containers are derived. Allows the successful build, install, and configure of Zimbra Collaboration Suite.

See [zmc-base README.md](./base/README.md)

### f9teams/zmc-build
This is a Docker container that will pull and build the master branch of https://github.com/f9teams/zm-build

See [zmc-build README.md](./build/README.md)
