# commands to run to get container working
# docker build --tag=zmc-dev:latest .
# docker network create --driver=bridge --subnet=10.0.0.0/24 zmc-bridge
# docker run --privileged --network=zmc-bridge --hostname=zmc-dev.f9teams.engineering --ip 10.0.0.2 -p 443:443 -p 7071:7071 -i -t zmc-dev:latest bash
# cp /etc/resolv.conf /tmp/zimbra/resolv.conf && umount /etc/resolv.conf && rm /etc/resolv.conf && ln -s /tmp/zimbra/resolv.conf /etc/resolv.conf
# cd zcs-*/ && ./install.sh
