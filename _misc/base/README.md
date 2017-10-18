Build using `docker build -t zimbra/zmc-dev:base .`

After build run the following process to compete setup.

```
docker run --privileged -i -t zimbra/zmc-base ./resolvconf-setup
docker ps -a # grab the container id
docker commit <container id> zimbra/zmc-base
docker push
```
