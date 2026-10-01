.PHONY: up down demo-unsafe-release demo-bad-deploy demo-suspicious-traffic bundle clean

up:
	@echo "Initializing Swarm Cluster & Secrets..."
	@docker swarm init 2>/dev/null || true
	@echo "super-secret-db-password" | docker secret create db_password - 2>/dev/null || true
	@echo "Deploying Axiler Multi-Tenant Stack..."
	@docker stack deploy -c swarm/docker-compose.yml axiler-stack
	@echo "Waiting for services to become healthy..."
	@sleep 12
	@docker service ls

down:
	@echo "Tearing down Axiler Stack..."
	@docker stack rm axiler-stack || true
	@docker secret rm db_password || true
	@echo "Clean up complete."

demo-unsafe-release:
	@bash scripts/demo-unsafe-release.sh

demo-bad-deploy:
	@bash scripts/demo-bad-deploy.sh

demo-suspicious-traffic:
	@bash scripts/demo-suspicious-traffic.sh

bundle:
	@bash scripts/make-offline-bundle.sh
