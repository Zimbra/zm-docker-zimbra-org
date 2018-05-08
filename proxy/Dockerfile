ARG DOCKER_REPO_NS_BASE
ARG DOCKER_BUILD_TAG
FROM ${DOCKER_REPO_NS_BASE}:${DOCKER_BUILD_TAG}

WORKDIR /tmp
RUN apt-get update && \
    apt-get install -y \ 
    zimbra-proxy \
    openssh-server && \
	apt-get clean

#Changes the default prot for ssh tool to the alredy exposed 23 see the Dokerfile and docker-compose related
# zmc-mailbox service
RUN sed -i -e 's/Port 22/Port 23/g' /etc/ssh/sshd_config
RUN service ssh start

WORKDIR /opt/zimbra
COPY common/Zimbra/TaskDispatch.pm common/lib/perl5/Zimbra/TaskDispatch.pm
COPY common/Zimbra/DockerLib.pm common/lib/perl5/Zimbra/DockerLib.pm
COPY common/healthcheck.py healthcheck.py
COPY proxy/entry-point.pl entry-point.pl
COPY proxy/changeZimbraPass changeZimbraPass

RUN chmod +x entry-point.pl \
             healthcheck.py \
             changeZimbraPass
             
RUN perl -c entry-point.pl

ENTRYPOINT ./entry-point.pl
EXPOSE 25 465 587 110 143 993 995 80 443 8080 8443 7071