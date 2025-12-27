include .env

ATTACH_SERVICES = \
	postgres.kws.services:lxdbr0:172.30.0.100/24 \
	adminer.kws.services:lxdbr0:172.30.0.101/24 \
	dnsmasq_kws:lxdbr0:172.30.0.102/24

define attach_services
	@echo "Waiting for containers to start..."
	@sleep 5
	@echo "Attaching services to bridge..."
	@set -e; \
	for triple in $(ATTACH_SERVICES); do \
		container=$${triple%%:*}; \
		tmp=$${triple#*:}; \
		bridge=$${tmp%%:*}; \
		ipcidr=$${tmp#*:}; \
		echo " -> $$container to $$bridge with $$ipcidr"; \
		max_attempts=10; \
		attempt=1; \
		while [ $$attempt -le $$max_attempts ]; do \
			if docker inspect -f '{{.State.Running}}' "$$container" 2>/dev/null | grep -q true; then \
				attach_to_bridge $$container $$bridge $$ipcidr && break; \
			fi; \
			echo "   Waiting for $$container to start (attempt $$attempt/$$max_attempts)..."; \
			sleep 2; \
			attempt=$$((attempt + 1)); \
		done; \
		if [ $$attempt -gt $$max_attempts ]; then \
			echo "   Warning: $$container did not start in time, skipping..."; \
		fi; \
	done
endef

up:
	docker compose up -d
	$(call attach_services)
	docker compose logs -f

down:
	docker compose down

stop:
	docker compose stop

start:
	docker compose start
	@echo "Waiting for containers to be ready..."
	@sleep 3
	$(call attach_services)
	docker compose logs -f

dv:
	docker volume rm kws_postgres_db_data_kws
	docker volume rm kws_redis_db_data_kws
	docker volume rm kws_mq_kws

dvs:
	docker volume rm kws_postgres_db_service_data

create_migration:
	migrate create -ext=sql -dir=src/internal/database/migrations -seq init

migrate_up:
	migrate -path=src/internal/database/migrations \
		-database "postgresql://${DB_USERNAME}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_DBNAME}?sslmode=disable" \
		-verbose up

migrate_down-%:
	migrate -path=src/internal/database/migrations \
		-database "postgresql://${DB_USERNAME}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_DBNAME}?sslmode=disable" \
		-verbose down $*

migrate_down-all:
	migrate -path=src/internal/database/migrations \
		-database "postgresql://${DB_USERNAME}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_DBNAME}?sslmode=disable" \
		-verbose down

.PHONY: up down stop start dv dvs create_migration migrate_up migrate_down migrate_down-all
