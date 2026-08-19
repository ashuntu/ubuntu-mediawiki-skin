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
	@echo "  URL:      http://localhost:8080"
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
extension:
	@docker compose exec -T mediawiki bash -c '\
		if [ ! -d extensions/UbuntuWiki ]; then \
			export COMPOSER_ALLOW_SUPERUSER=1; \
			command -v composer >/dev/null 2>&1 || { \
				php -r "copy(\"https://getcomposer.org/installer\", \"/tmp/composer-setup.php\");" && \
				php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer --quiet && \
				rm /tmp/composer-setup.php; \
			}; \
			composer update ubuntu/mediawiki-ubuntu-extension --with-all-dependencies --no-interaction --no-progress; \
		fi'

LocalSettings.php:
	cp LocalSettings.example.php LocalSettings.php
	@echo "Created LocalSettings.php from LocalSettings.example.php — edit it before running setup."
