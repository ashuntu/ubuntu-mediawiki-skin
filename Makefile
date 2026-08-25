.PHONY: setup deploy up down clean extension

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

setup: LocalSettings.php
	$(COMPOSE) up -d
	$(MAKE) --no-print-directory extension
	@echo "Waiting for database..."
	@until $(MW_T) bash -c "php -r \"new mysqli('db', 'mediawiki', 'mediawiki', 'mediawiki');\"" > /dev/null 2>&1; do printf '.'; sleep 2; done
	@echo " ready."
	$(MW) php maintenance/run.php install \
		--dbtype mysql --dbserver db --dbname mediawiki \
		--dbuser mediawiki --dbpass mediawiki \
		--pass '$(ADMIN_PASSWORD)' \
		"Ubuntu wiki" admin
	$(COMPOSE) cp LocalSettings.php mediawiki:/var/www/html/LocalSettings.php
	@echo ""
	@echo "Setup complete!"
	@echo "  URL:      http://localhost:$(PORT)"
	@echo "  Username: admin"
	@echo "  Password: $(ADMIN_PASSWORD)"

deploy: LocalSettings.php
	$(COMPOSE) cp LocalSettings.php mediawiki:/var/www/html/LocalSettings.php

up: LocalSettings.php
	$(COMPOSE) up -d
	$(MAKE) --no-print-directory extension
	$(COMPOSE) cp LocalSettings.php mediawiki:/var/www/html/LocalSettings.php

down:
	$(COMPOSE) down

clean:
	$(COMPOSE) down -v

# Install the UbuntuWiki extension (required by the skin) into the container
# via composer, using the composer.local.json mounted by docker-compose.
# The extension repo is public, so no authentication is needed.
# The existence check runs inside the same shell as the install: each recipe
# line runs in its own shell, so a separate-line `exit 0` would not skip it.
extension:
	$(MW_T) bash -c '\
		if [ -d extensions/UbuntuWiki ]; then \
			echo "UbuntuWiki extension already installed, skipping."; \
			exit 0; \
		fi; \
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
		fi'

LocalSettings.php:
	cp LocalSettings.example.php LocalSettings.php
	@echo "Created LocalSettings.php from LocalSettings.example.php — edit it before running setup."
