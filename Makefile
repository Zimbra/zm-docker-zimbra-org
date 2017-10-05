all: .build-all

SERVICES = 
SERVICES += ldap
SERVICES += mysql
SERVICES += mta
SERVICES += mailbox1
SERVICES += mailbox2
SERVICES += proxy

################################################################

BUILD_IMAGES = $(patsubst %,.build-%,$(SERVICES))

.build-all: $(BUILD_IMAGES) docker-compose.yml
	docker-compose build

.build-base: _base/*
	cd _base && docker build . -t zimbra/zmc-base

$(BUILD_IMAGES): .build-% : .build-base docker-compose.yml
	docker-compose build $*

################################################################

.config: config.in
	cat config.in > .config

up: .config .build-all
	@docker-compose down
	@docker-compose up -d
	@echo Run: docker-compose logs -f

################################################################
