.DEFAULT_GOAL := help

.PHONY: help setup up down restart clean distclean settings db-update \
	extension extension-update logs shell run jobs

# Password for the initial admin account created by `make setup`
ADMIN_PASSWORD := UbuntuWiki2026!

# Host port for the test wiki; override with UBUNTU_SKIN_PORT=<port> to run
# alongside other MediaWiki environments (see docker-compose.yml).
# Distinct from the extension repo's UBUNTU_WIKI_PORT (default 8088) so both
# environments can run at once.
PORT := $(or $(UBUNTU_SKIN_PORT),8081)
export UBUNTU_SKIN_PORT

COMPOSE := docker compose
MW := $(COMPOSE) exec mediawiki
MW_T := $(COMPOSE) exec -T mediawiki

# Shell snippet (run inside the container) that makes composer and unzip
# available, then updates the UbuntuWiki extension via the composer.local.json
# mounted by docker-compose. The extension repo is public, so no
# authentication is needed. Composer is installed with the officially
# documented phar + sha384 signature check. Quoting: single-quoted shell
# string, so double quotes inside are written as \" (escaped for make).
define EXTENSION_SETUP
export COMPOSER_ALLOW_SUPERUSER=1; \
command -v composer >/dev/null 2>&1 || { \
	php -r "copy(\"https://getcomposer.org/installer\", \"/tmp/composer-setup.php\");" && \
	php -r "copy(\"https://composer.github.io/installer.sig\", \"/tmp/composer-setup.sig\");" && \
	php -r "if (hash_file(\"sha384\", \"/tmp/composer-setup.php\") !== trim(file_get_contents(\"/tmp/composer-setup.sig\"))) { fwrite(STDERR, \"ERROR: Invalid Composer installer signature. Aborting.\\n\"); exit(1); }" && \
	php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer --quiet && \
	rm -f /tmp/composer-setup.php /tmp/composer-setup.sig; \
}; \
command -v unzip >/dev/null 2>&1 || { apt-get update -qq && apt-get install -y -qq unzip; }; \
if [ -f composer.lock ]; then \
	composer update ubuntu/mediawiki-ubuntu-extension --with-all-dependencies --no-interaction --no-progress; \
else \
	composer update --no-interaction --no-progress; \
fi
endef

## help: Show this help (default target)
help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@grep -Eh '^## [a-zA-Z_-]+: ' $(MAKEFILE_LIST) | sed -e 's/^## //' | sort | awk -F': ' '{printf "  %-16s %s\n", $$1, $$2}'

## setup: Create and initialize the wiki from scratch (installs MediaWiki)
setup: up
	@echo "Waiting for database..."
	@until $(MW_T) bash -c "php -r \"new mysqli('db', 'mediawiki', 'mediawiki', 'mediawiki');\"" > /dev/null 2>&1; do printf '.'; sleep 2; done
	@echo " ready."
	$(MW) php maintenance/run.php install \
		--dbtype mysql --dbserver db --dbname mediawiki \
		--dbuser mediawiki --dbpass mediawiki \
		--pass '$(ADMIN_PASSWORD)' \
		"Ubuntu wiki" admin
	@# The installer writes its own LocalSettings.php; overwrite with ours
	$(COMPOSE) cp LocalSettings.php mediawiki:/var/www/html/LocalSettings.php
	$(MAKE) --no-print-directory db-update
	@echo ""
	@echo "Setup complete!"
	@echo "  URL:      http://localhost:$(PORT)"
	@echo "  Username: admin"
	@echo "  Password: $(ADMIN_PASSWORD)"

## up: Start the containers (runs `extension`; copies LocalSettings.php if installed)
up: LocalSettings.php
	$(COMPOSE) up -d
	$(MAKE) --no-print-directory extension
	@# Only copy settings if the wiki is already installed; the installer
	@# refuses to run when LocalSettings.php already exists. Probe the DB
	@# directly (maintenance scripts need LocalSettings.php themselves, so
	@# they cannot answer "am I installed?" before the file exists). Wait for
	@# the DB first: after a fresh `up`/`restart` MariaDB may still be
	@# initializing, and the probe would wrongly conclude "not installed".
	@until $(MW_T) bash -c "php -r \"new mysqli('db', 'mediawiki', 'mediawiki', 'mediawiki');\"" > /dev/null 2>&1; do sleep 2; done
	@if $(MW_T) bash -c "php -r \"exit((new mysqli('db', 'mediawiki', 'mediawiki', 'mediawiki'))->query('SELECT 1 FROM page LIMIT 1') ? 0 : 1);\"" > /dev/null 2>&1; then \
		$(COMPOSE) cp LocalSettings.php mediawiki:/var/www/html/LocalSettings.php; \
	else \
		echo "Wiki not installed yet; skipping LocalSettings.php copy (run 'make setup')."; \
	fi

## down: Stop and remove the containers
down:
	$(COMPOSE) down

## restart: Restart the containers (`down` then `up`)
restart: down up

## clean: Stop the containers and delete the database volume (DESTRUCTIVE)
clean:
	$(COMPOSE) down -v

## distclean: `clean` plus delete the generated LocalSettings.php (DESTRUCTIVE)
distclean: clean
	rm -f LocalSettings.php

## settings: Copy LocalSettings.php into the container and run DB update
settings: LocalSettings.php
	$(COMPOSE) cp LocalSettings.php mediawiki:/var/www/html/LocalSettings.php
	$(MAKE) --no-print-directory db-update

## db-update: Run the MediaWiki database update script
db-update:
	$(MW_T) php maintenance/run.php update --quick

# Install the UbuntuWiki extension (required by the skin) into the container.
# The existence check runs inside the same shell as the install: each recipe
# line runs in its own shell, so a separate-line `exit 0` would not skip it.
## extension: Install the UbuntuWiki extension into the container (skips if present)
extension:
	$(MW_T) bash -c '\
		if [ -d extensions/UbuntuWiki ]; then \
			echo "UbuntuWiki extension already installed, skipping."; \
			exit 0; \
		fi; \
		$(EXTENSION_SETUP)'

## extension-update: Force-update the UbuntuWiki extension, even if already installed
extension-update:
	$(MW_T) bash -c '$(EXTENSION_SETUP)'

## logs: Follow the mediawiki container logs (Ctrl-C to stop)
logs:
	$(COMPOSE) logs -f mediawiki

## shell: Open an interactive bash shell in the mediawiki container
shell:
	$(MW) bash

## jobs: Force-run the MediaWiki job queue
jobs:
	$(MW_T) php maintenance/run.php runJobs

## run: Run a MediaWiki maintenance script, e.g. make run SCRIPT="runJobs --maxjobs 5"
run:
	$(MW_T) php maintenance/run.php $(SCRIPT)

LocalSettings.php:
	cp LocalSettings.example.php LocalSettings.php
	@echo "Created LocalSettings.php from LocalSettings.example.php — edit it before running setup."
