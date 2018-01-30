all: build-all

SHELL = bash

################################################################
# CUSTOMIZATION VARIABLES - custom values can be can be specified for the following:
#
# E.g.:
#    make OPENSSL_CNF=... DOCKER_REPO_NS=...
#     or
#         OPENSSL_CNF=... DOCKER_REPO_NS=... make
#

OPENSSL_CNF ?= _conf/openssl.cnf
PACKAGE_CNF ?= _conf/pkg-list
PACKAGE_KEY ?= _conf/pkg-key

DOCKER_REPO_NS    ?= zimbra
DOCKER_BUILD_TAG  ?= latest-build
DOCKER_CACHE_TAG  ?= ${DOCKER_BUILD_TAG}
DOCKER_PUSH_TAG   ?=
DOCKER_PULL_TAG   ?=
DOCKER_STACK_NAME ?= zm-docker

################################################################

IMAGE_NAMES      = $(shell sed -n -e '/image:.*\/zmc-*/ { s,.*/,,; s,:.*,,; p; }' docker-compose.yml) zmc-base
LOCAL_SRC_DIR    = $(shell test -z "$$DOCKER_HOST" && echo .)/
DOCKER_NODE_ADDR = $(shell docker node inspect --format '{{ .Status.Addr }}' self)

build-all: $(patsubst %,build-%,$(IMAGE_NAMES))
	@mkdir -p _cache
	@echo ${DOCKER_BUILD_TAG} > _cache/id.txt
	docker images

push-all: $(patsubst %,push-%,$(IMAGE_NAMES))

pull-all: $(patsubst %,pull-%,$(IMAGE_NAMES))

################################################################

_conf/pkg-list: _conf/pkg-list.in
	cp $< $@

_conf/pkg-key: _conf/pkg-key.in
	cp $< $@

################################################################

build-zmc-base: _base/* ${PACKAGE_CNF} ${PACKAGE_KEY}
	@echo "-----------------------------------------------------------------"
	@echo Building zmc-base
	@echo
	docker build \
	    --build-arg "PACKAGE_CNF=${PACKAGE_CNF}" \
	    --build-arg "PACKAGE_KEY=${PACKAGE_KEY}" \
	    --cache-from '${DOCKER_REPO_NS}/zmc-base:${DOCKER_CACHE_TAG}' \
	    --tag        '${DOCKER_REPO_NS}/zmc-base:${DOCKER_BUILD_TAG}' \
	    --file       _base/Dockerfile \
	    .
	@echo "-----------------------------------------------------------------"

build-zmc-%: build-zmc-base docker-compose.yml
	@echo "-----------------------------------------------------------------"
	@echo Building zmc-$*
	@echo
	DOCKER_REPO_NS=${DOCKER_REPO_NS} \
	    DOCKER_BUILD_TAG=${DOCKER_BUILD_TAG} \
	    DOCKER_CACHE_TAG=${DOCKER_CACHE_TAG} \
	    LOCAL_SRC_DIR=${LOCAL_SRC_DIR} \
	    docker-compose build 'zmc-$*'
	@echo "-----------------------------------------------------------------"

push-zmc-%: push-prereq
	@echo "-----------------------------------------------------------------"
	@echo Pushing ${DOCKER_REPO_NS}/zmc-$*:${DOCKER_PUSH_TAG}
	@echo
	@docker tag '${DOCKER_REPO_NS}/zmc-$*:${DOCKER_BUILD_TAG}' '${DOCKER_REPO_NS}/zmc-$*:${DOCKER_PUSH_TAG}'
	docker push '${DOCKER_REPO_NS}/zmc-$*:${DOCKER_PUSH_TAG}'
	@echo "-----------------------------------------------------------------"

pull-zmc-%: pull-prereq
	@echo "-----------------------------------------------------------------"
	@echo Pulling ${DOCKER_REPO_NS}/zmc-$*:${DOCKER_PULL_TAG}
	@echo
	docker pull '${DOCKER_REPO_NS}/zmc-$*:${DOCKER_PULL_TAG}'
	@echo "-----------------------------------------------------------------"

################################################################

push-prereq:
	@if [ '${DOCKER_PUSH_TAG}' = '' ]; \
	 then \
	       echo "-------------------------------------------------" \
	    && echo " Error: 'DOCKER_PUSH_TAG=...' is required for push      " \
	    && echo "-------------------------------------------------" \
	    && false; \
	 fi
	@if [ '${DOCKER_PUSH_TAG}' = 'latest-build' ]; \
	 then \
	       echo "-------------------------------------------------" \
	    && echo " Error: 'DOCKER_PUSH_TAG=latest-build' is forbidden     " \
	    && echo "-------------------------------------------------" \
	    && false; \
	 fi

pull-prereq:
	@if [ '${DOCKER_PULL_TAG}' = '' ]; \
	 then \
	       echo "-------------------------------------------------" \
	    && echo " Error: 'DOCKER_PULL_TAG=...' is required for pull      " \
	    && echo "-------------------------------------------------" \
	    && false; \
	 fi

################################################################

CONFIGS =
CONFIGS += .config/domain_name
CONFIGS += .config/admin_account_name
CONFIGS += .config/spam_account_name
CONFIGS += .config/ham_account_name
CONFIGS += .config/virus_quarantine_account_name
CONFIGS += .config/gal_sync_account_name
CONFIGS += .config/av_notify_email
CONFIGS += .config/zimbra_ldap_userdn
CONFIGS += .config/tzdata_area
CONFIGS += .config/tzdata_zone
CONFIGS += .config/time_zone_id

.config/.init:
	mkdir .config
	touch "$@"

.config/domain_name: .config/.init
	@echo zmc.com > $@
	@echo Created default $@ : $$(cat $@)

.config/admin_account_name: .config/.init
	@echo admin > $@
	@echo Created default $@ : $$(cat $@)

.config/spam_account_name: .config/.init
	@echo spam.$$(LC_ALL=C tr -cd '0-9a-z_' < /dev/urandom | head -c 8) > $@
	@echo Created default $@ : $$(cat $@)

.config/ham_account_name: .config/.init
	@echo ham.$$(LC_ALL=C tr -cd '0-9a-z_' < /dev/urandom | head -c 8) > $@
	@echo Created default $@ : $$(cat $@)

.config/virus_quarantine_account_name: .config/.init
	@echo virus-quarantine.$$(LC_ALL=C tr -cd '0-9a-z_' < /dev/urandom | head -c 8) > $@
	@echo Created default $@ : $$(cat $@)

.config/gal_sync_account_name: .config/.init
	@echo gal-sync.$$(LC_ALL=C tr -cd '0-9a-z_' < /dev/urandom | head -c 8) > $@
	@echo Created default $@ : $$(cat $@)

.config/av_notify_email: .config/domain_name
	@echo admin@$$(cat $<) > $@
	@echo Created default $@ : $$(cat $@)

.config/zimbra_ldap_userdn: .config/zimbra_ldap_userdn
	@echo uid=zimbra,cn=admins,cn=zimbra > $@
	@echo Created default $@ : $$(cat $@)

.config/tzdata_area: .config/tzdata_area
	@echo US > $@
	@echo Created default $@ : $$(cat $@)

.config/tzdata_zone: .config/tzdata_area
	@echo Pacific > $@
	@echo Created default $@ : $$(cat $@)

.config/time_zone_id: .config/time_zone_id
	@echo America/Los_Angeles > $@
	@echo Created default $@ : $$(cat $@)

init-configs: $(CONFIGS)
	@echo All Configs Created!

################################################################

PASSWORDS += .secrets/ldap.nginx_password
PASSWORDS += .secrets/ldap.nginx_password
PASSWORDS += .secrets/ldap.master_password
PASSWORDS += .secrets/ldap.root_password
PASSWORDS += .secrets/ldap.replication_password
PASSWORDS += .secrets/ldap.amavis_password
PASSWORDS += .secrets/ldap.postfix_password
PASSWORDS += .secrets/mysql.password
PASSWORDS += .secrets/admin_account_password
PASSWORDS += .secrets/spam_account_password
PASSWORDS += .secrets/ham_account_password
PASSWORDS += .secrets/virus_quarantine_account_password

.secrets/.init:
	mkdir .secrets
	touch "$@"

.secrets/admin_account_password: .secrets/.init
	@echo test123 > $@
	@echo Created default $@ : $$(cat $@)

.secrets/%password: .secrets/.init
	@LC_ALL=C tr -cd '0-9a-z_' < /dev/urandom | head -c 15 > $@;
	@echo Created default $@

init-passwords: $(PASSWORDS)
	@echo All Passwords Created!

################################################################

KEYS =
KEYS += .keystore/ca.key
KEYS += .keystore/ca.pem
KEYS += .keystore/ldap.key
KEYS += .keystore/ldap.crt
KEYS += .keystore/mta.key
KEYS += .keystore/mta.crt
KEYS += .keystore/mailbox.key
KEYS += .keystore/mailbox.crt
KEYS += .keystore/proxy.key
KEYS += .keystore/proxy.crt

.keystore/.init:
	mkdir -p         .keystore/demoCA/newcerts
	rm -f            .keystore/demoCA/index.txt
	touch            .keystore/demoCA/index.txt
	echo    "1000" > .keystore/demoCA/serial
	touch $@

.keystore/%.key: ${OPENSSL_CNF} .keystore/.init
	OPENSSL_CONF=${OPENSSL_CNF} openssl genrsa -out $@ 2048

.keystore/ca.pem: ${OPENSSL_CNF} .keystore/ca.key
	OPENSSL_CONF=${OPENSSL_CNF} openssl req -batch -nodes \
	    -new \
	    -sha256 \
	    -subj '/O=CA/OU=Zimbra Collaboration Server/CN=zmc-ldap' \
	    -days 1825 \
	    -key .keystore/ca.key \
	    -x509 \
	    -out $@

.keystore/%.csr: ${OPENSSL_CNF} .keystore/%.key
	OPENSSL_CONF=${OPENSSL_CNF} openssl req -batch -nodes \
	    -new \
	    -sha256 \
	    -subj "/OU=Zimbra Collaboration Server/CN=zmc-$*" \
	    -days 1825 \
	    -key .keystore/$*.key \
	    -out $@

.keystore/%.crt: ${OPENSSL_CNF} .keystore/%.csr .keystore/ca.pem .keystore/ca.key
	OPENSSL_CONF=${OPENSSL_CNF} openssl ca -batch -notext \
	    -policy policy_anything \
	    -days 1825 \
	    -md sha256 \
	    -in .keystore/$*.csr \
	    -cert .keystore/ca.pem \
	    -keyfile .keystore/ca.key \
	    -extensions v3_req \
	    -out $@

init-keys: $(KEYS)
	@echo All Keys Created!

################################################################

up: .up.lock

.up.lock: init-configs init-passwords init-keys docker-compose.yml
	@docker swarm init 2>/dev/null; true
	DOCKER_REPO_NS=${DOCKER_REPO_NS} \
	    DOCKER_BUILD_TAG=${DOCKER_BUILD_TAG} \
	    DOCKER_CACHE_TAG=${DOCKER_CACHE_TAG} \
	    LOCAL_SRC_DIR=${LOCAL_SRC_DIR} \
	    docker stack deploy -c docker-compose.yml '${DOCKER_STACK_NAME}'
	@touch .up.lock

down:
	@docker stack rm '${DOCKER_STACK_NAME}'
	@rm -f .up.lock

TAIL_SZ ?= 5

logs:
	@for i in $$(docker stack services ${DOCKER_STACK_NAME} --format "table {{.ID}}" | sed -e 1d); \
	 do \
	    echo ----------------------------------; \
	    docker service logs --tail ${TAIL_SZ} $$i; \
	 done
	@echo ----------------------------------;

compile:
	@docker build -t zm-docker-build ${PWD}/build
# using a volume mounted from a MacOS host will fail when rsync tries to copy file attributes (chown)
# using a docker volume instead
	@docker volume create ZM-BUILDS
	$(eval WPWD=$(shell bash -c "echo ${PWD} | sed -e 's/^\/mnt//'"))
	docker run --rm -it -v ZM-BUILDS:/home/build/zm/BUILDS -v $(WPWD)/build/config:/home/build/config zm-docker-build
	@rm -rf ./BUILDS
	@mkdir -p ./BUILDS
# mount the docker volume containing the build output so that we can CP it to the host
# necessary because the docker volume can not be leveraged during docker-compose build in zm-docker
	@docker run -d --name ZM-BUILD -v ZM-BUILDS:/BUILDS busybox
	docker cp ZM-BUILD:/BUILDS/. ./BUILDS
	@-docker container rm -f ZM-BUILD

clean: down
	rm -rf .config .secrets .keystore

################################################################

TEST_SLEEP_TIME = 5
TEST_MAX_RETRIES = 80

test-zmc-%: up
	@echo "-----------------------------------------------------------------"
	@echo Testing zmc-$*
	@echo
	@echo Test.... - FIXME - this is a stub
	@echo "-----------------------------------------------------------------"

get-curl:
	docker pull nhoag/curl

test: $(patsubst %,test-%,$(IMAGE_NAMES)) up get-curl
	@echo "-----------------------------------------------------------------"
	@echo Testing overall
	@echo
	@echo FIXME - RUDIMENTARY TEST
	@echo "-----------------------------------------------------------------"
	failure=1; \
	n=0; \
	while (( n++ < ${TEST_MAX_RETRIES} )); \
	do \
	    clear 2>/dev/null; \
	    echo "================================================================="; \
	    echo "CURRENT TAIL LOGS: ($$n tries of ${TEST_MAX_RETRIES})"; \
	    echo "================================================================="; \
	    echo; \
	    $(MAKE) -s logs TAIL_SZ=5; \
	    echo; \
	    if [ "$$(docker run -it nhoag/curl curl --max-time 5 -k --silent --output /dev/null --write-out "%{http_code}" https://${DOCKER_NODE_ADDR}:8443/)" == "200" ]; \
	    then \
	       echo "================================================================="; \
	       echo "TEST SUCCESSFUL (in $$n tries)"; \
	       echo "================================================================="; \
	       failure=0; \
	       break; \
	    fi; \
	    echo "================================================================="; \
	    echo "TEST WAITING FOR RESULT ($$n tries of ${TEST_MAX_RETRIES})."; \
	    echo "================================================================="; \
	    echo "Retrying after ${TEST_SLEEP_TIME} sec..."; \
	    sleep ${TEST_SLEEP_TIME}; \
	done; \
	echo "Dumping logs to _out/container-logs.txt..."; \
	mkdir -p _out; \
	$(MAKE) -s logs TAIL_SZ=all | perl -MTerm::ANSIColor=colorstrip -ne 'print colorstrip($$_)' > _out/container-logs.txt 2>&1; \
	exit $$failure

################################################################
