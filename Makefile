all: build-all

################################################################

build-all: build-base docker-compose.yml
	docker-compose build

build-base: _base/*
	cd _base && docker build . -t zimbra/zmc-base

################################################################

# Uncomment the following (and update the path accordingly) if you 
# are using private ssl configuration
# OPENSSL_CONF ?= ${HOME}/Projects/z/zm-docker/zimbra/ca/zmssl.cnf

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
	@echo spam.$$(tr -cd '0-9a-z_' < /dev/urandom | head -c 8) > $@
	@echo Created default $@ : $$(cat $@)

.config/ham_account_name: .config/.init
	@echo ham.$$(tr -cd '0-9a-z_' < /dev/urandom | head -c 8) > $@
	@echo Created default $@ : $$(cat $@)

.config/virus_quarantine_account_name: .config/.init
	@echo virus-quarantine.$$(tr -cd '0-9a-z_' < /dev/urandom | head -c 8) > $@
	@echo Created default $@ : $$(cat $@)

.config/gal_sync_account_name: .config/.init
	@echo gal-sync.$$(tr -cd '0-9a-z_' < /dev/urandom | head -c 8) > $@
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
	@echo admin123 > $@
	@echo Created default $@ : $$(cat $@)

.secrets/%password: .secrets/.init
	@tr -cd '0-9a-z_' < /dev/urandom | head -c 15 > $@;
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
	echo -n        > .keystore/demoCA/index.txt
	echo -n "1000" > .keystore/demoCA/serial
	touch $@

.keystore/%.key: .keystore/.init
	export OPENSSL_CONF=${OPENSSL_CONF}; openssl genrsa -out $@ 2048

.keystore/ca.pem: .keystore/ca.key
	export OPENSSL_CONF=${OPENSSL_CONF}; openssl req -batch -nodes \
	    -new \
	    -sha256 \
	    -subj '/O=CA/OU=Zimbra Collaboration Server/CN=zmc-ldap' \
	    -days 1825 \
	    -key .keystore/ca.key \
	    -x509 \
	    -out $@
	export OPENSSL_CONF=${OPENSSL_CONF}; openssl req -batch -nodes \
	    -new -sha256 \
	    -subj '/O=CA/OU=Zimbra Collaboration Server/CN=zmc-ldap' \
	    -days 1825 \
	    -out .keystore/ca1.pem \
	    -newkey rsa:2048 \
	    -keyout .keystore/ca1.key \
	    -extensions v3_ca -x509

.keystore/%.csr: .keystore/%.key
	export OPENSSL_CONF=${OPENSSL_CONF}; openssl req -batch -nodes \
	    -new \
	    -sha256 \
	    -subj "/OU=Zimbra Collaboration Server/CN=zmc-$*" \
	    -days 1825 \
	    -key .keystore/$*.key \
	    -out $@

.keystore/%.crt: .keystore/%.csr .keystore/ca.pem .keystore/ca.key
	cd .keystore && \
	export OPENSSL_CONF=${OPENSSL_CONF}; openssl ca -batch -notext \
	    -policy policy_anything \
	    -days 1825 \
	    -md sha256 \
	    -in ../.keystore/$*.csr \
	    -cert ../.keystore/ca.pem \
	    -keyfile ../.keystore/ca.key \
	    -extensions v3_req \
	    -out ../$@

init-keys: $(KEYS)
	@echo All Keys Created!

################################################################

up: init-configs init-passwords init-keys
	@docker swarm init 2>/dev/null; echo
	docker stack deploy -c ./docker-compose.yml '$(shell basename "$$PWD")'

down:
	@docker stack rm $(shell basename "$$PWD")


logs:
	@for i in $$(docker ps --format "table {{.Names}}" | grep '$(shell basename "$$PWD")_'); \
	 do \
	    echo ----------------------------------; \
	    docker service logs --tail 5 $$i; \
	 done

clean: down
	rm -rf .config .secrets .keystore
