all: build-all

################################################################

build-all: build-base docker-compose.yml
	docker-compose build

build-base: _base/*
	cd _base && docker build . -t zimbra/zmc-base

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

up: init-configs init-passwords
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
	rm -rf .config .secrets
