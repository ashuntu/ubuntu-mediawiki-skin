.PHONY: setup deploy up down clean extension

setup: LocalSettings.php
	docker compose up -d
	$(MAKE) --no-print-directory extension
	@echo "Waiting for database..."
	@until docker compose exec -T mediawiki bash -c "php -r \"new mysqli('db', 'mediawiki', 'mediawiki', 'mediawiki');\"" > /dev/null 2>&1; do printf '.'; sleep 2; done
	@echo " ready."
	docker compose exec mediawiki php maintenance/run.php install \
		--dbtype mysql --dbserver db --dbname mediawiki \
		--dbuser mediawiki --dbpass mediawiki \
		--pass UbuntuWiki2026! \
		"Ubuntu wiki" admin
	docker compose cp LocalSettings.php mediawiki:/var/www/html/LocalSettings.php
	@echo ""
	@echo "Setup complete!"
	@echo "  URL:      http://localhost:8081"
	@echo "  Username: admin"
	@echo "  Password: UbuntuWiki2026!"

deploy: LocalSettings.php
	docker compose cp LocalSettings.php mediawiki:/var/www/html/LocalSettings.php

up: LocalSettings.php
	docker compose up -d
	$(MAKE) --no-print-directory extension
	docker compose cp LocalSettings.php mediawiki:/var/www/html/LocalSettings.php

down:
	docker compose down

clean:
	docker compose down -v

# Install the UbuntuWiki extension (required by the skin) into the container
# via composer, using the composer.local.json mounted by docker-compose.
# The extension repo is public, so no authentication is needed.
# The existence check runs inside the same shell as the install: each recipe
# line runs in its own shell, so a separate-line `exit 0` would not skip it.
extension:
	docker compose exec -T mediawiki bash -c '\
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
