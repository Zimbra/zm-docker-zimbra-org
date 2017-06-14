Build using `docker build -t f9teams/zmc-dev:base .`

After build run the following process to compete setup.

```
docker run --privileged -i -t f9teams/zmc-base ./resolvconf-setup
docker ps -a # grab the container id
docker commit <container id> f9teams/zmc-base
docker push
```
