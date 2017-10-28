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

IMAGE_NAMES   = $(shell sed -n -e '/image:.*\/\<zmc-*/ { s,.*/,,; s,:.*,,; p; }' docker-compose.yml) zmc-base
LOCAL_SRC_DIR = $(shell test -z "$$DOCKER_HOST" && echo .)/

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

logs:
	@for i in $$(docker ps --format "table {{.Names}}" | grep '${DOCKER_STACK_NAME}_'); \
	 do \
	    echo ----------------------------------; \
	    docker service logs --tail 5 $$i; \
	 done

clean: down
	rm -rf .config .secrets .keystore


################################################################
