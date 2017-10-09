all: build-all

################################################################

build-all: build-base docker-compose.yml
	docker-compose build

build-base: _base/*
	cd _base && docker build . -t zimbra/zmc-base

################################################################

SETTINGS =
SETTINGS += .config/domain_name
SETTINGS += .config/admin_account_name
SETTINGS += .config/spam_account_name
SETTINGS += .config/ham_account_name
SETTINGS += .config/virus_quarantine_account_name
SETTINGS += .config/gal_sync_account_name
SETTINGS += .config/av_notify_email

SETTINGS += .secrets/ldap.nginx_password
SETTINGS += .secrets/ldap.nginx_password
SETTINGS += .secrets/ldap.master_password
SETTINGS += .secrets/ldap.root_password
SETTINGS += .secrets/ldap.replication_password
SETTINGS += .secrets/ldap.amavis_password
SETTINGS += .secrets/ldap.postfix_password
SETTINGS += .secrets/mysql.password
SETTINGS += .secrets/admin_account_password
SETTINGS += .secrets/spam_account_password
SETTINGS += .secrets/ham_account_password
SETTINGS += .secrets/virus_quarantine_account_password

.config:
	mkdir .config

.config/domain_name: .config
	@echo zmc.com > $@
	@echo Created default $@ : $$(cat $@)

.config/admin_account_name: .config
	@echo admin > $@
	@echo Created default $@ : $$(cat $@)

.config/spam_account_name: .config
	@echo spam.$$(tr -cd '0-9a-z_' < /dev/urandom | head -c 8) > $@
	@echo Created default $@ : $$(cat $@)

.config/ham_account_name: .config
	@echo ham.$$(tr -cd '0-9a-z_' < /dev/urandom | head -c 8) > $@
	@echo Created default $@ : $$(cat $@)

.config/virus_quarantine_account_name: .config
	@echo virus-quarantine.$$(tr -cd '0-9a-z_' < /dev/urandom | head -c 8) > $@
	@echo Created default $@ : $$(cat $@)

.config/gal_sync_account_name: .config
	@echo gal-sync.$$(tr -cd '0-9a-z_' < /dev/urandom | head -c 8) > $@
	@echo Created default $@ : $$(cat $@)

.config/av_notify_email: .config/domain_name
	@echo admin@$$(cat $<) > $@
	@echo Created default $@ : $$(cat $@)

.secrets:
	mkdir .secrets

.secrets/admin_account_password: .secrets
	@echo admin123 > $@
	@echo Created default $@ : $$(cat $@)

.secrets/%password: .secrets
	@tr -cd '0-9a-z_' < /dev/urandom | head -c 15 > $@;
	@echo Created default $@

init-settings: $(SETTINGS)
	@echo All Settings Created!

################################################################

up: init-settings
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
