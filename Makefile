.PHONY: config lint up bootstrap verify drill down reset

config:
	docker compose config --quiet

lint:
	docker run --rm --entrypoint sh -v "$(CURDIR):/mnt:ro" koalaman/shellcheck-alpine:v0.10.0 -c 'shellcheck /mnt/scripts/*.sh /mnt/postgres/*/*.sh'

up:
	docker compose up --detach --wait --wait-timeout 240

bootstrap:
	./scripts/bootstrap.sh

verify:
	./scripts/verify.sh

drill:
	./scripts/kafka-failure-drill.sh

down:
	docker compose down

reset:
	docker compose down --volumes --remove-orphans
