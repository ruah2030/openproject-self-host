.PHONY: help install start stop restart logs logs-all status clean nginx-reload ps db shell-openproject shell-traefik backup info version

help:
	@echo "╔════════════════════════════════════════════════════════════╗"
	@echo "║          OpenProject Deployment - Quick Commands           ║"
	@echo "╚════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📦 Installation:"
	@echo "   make install          - Full installation (setup.sh)"
	@echo ""
	@echo "🚀 Service management:"
	@echo "   make start            - Start the containers"
	@echo "   make stop             - Stop the containers"
	@echo "   make restart          - Restart the containers"
	@echo "   make status           - Show service status"
	@echo "   make logs             - Follow live logs"
	@echo "   make logs-all         - Logs of all containers"
	@echo ""
	@echo "🐳 Docker:"
	@echo "   make ps               - List containers"
	@echo "   make shell-openproject- Shell into OpenProject"
	@echo "   make shell-traefik    - Shell into Traefik"
	@echo ""
	@echo "💾 Database (PostgreSQL built into the container):"
	@echo "   make db               - Open a PostgreSQL shell"
	@echo "   make backup           - Back up the database"
	@echo ""
	@echo "📊 Information:"
	@echo "   make info             - Deployment information"
	@echo "   make version          - Installed versions"
	@echo ""
	@echo "🧹 Maintenance:"
	@echo "   make clean            - Remove all containers"
	@echo ""

install:
	@echo "🚀 Starting installation..."
	@bash setup.sh

start:
	@echo "▶️  Starting services..."
	docker-compose up -d
	@echo "✅ Services started"
	@make status

stop:
	@echo "⏹️  Stopping services..."
	docker-compose down
	@echo "✅ Services stopped"

restart:
	@echo "🔄 Restarting services..."
	docker-compose restart
	@echo "✅ Services restarted"
	@make status

status:
	@echo ""
	@echo "📊 Docker container status:"
	docker-compose ps
	@echo ""
	@echo "📊 Nginx status:"
	@sudo systemctl status nginx --no-pager 2>/dev/null || echo "Nginx status unavailable"
	@echo ""

logs:
	@echo "📋 OpenProject logs (Ctrl+C to stop):"
	docker-compose logs -f openproject

logs-all:
	@echo "📋 All container logs (Ctrl+C to stop):"
	docker-compose logs -f

nginx-reload:
	@echo "🔄 Reloading Nginx..."
	@sudo nginx -t && sudo systemctl reload nginx
	@echo "✅ Nginx reloaded"

ps:
	@echo "🐳 Running Docker containers:"
	docker ps
	@echo ""
	@echo "All containers:"
	docker ps -a

shell-openproject:
	@echo "🐚 Opening OpenProject shell..."
	docker-compose exec openproject bash

shell-traefik:
	@echo "🐚 Opening Traefik shell..."
	docker-compose exec traefik sh

db:
	@echo "💾 Connecting to PostgreSQL (built into the OpenProject container)..."
	docker-compose exec openproject su postgres -c "psql openproject"

backup:
	@echo "💾 Backing up the PostgreSQL database..."
	@mkdir -p ./backups
	docker-compose exec -T openproject su postgres -c "pg_dump openproject" > ./backups/openproject_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "✅ Backup created in ./backups/"
	@ls -lh ./backups/

clean:
	@echo "🧹 Removing all containers..."
	docker-compose down -v
	@echo "✅ Containers removed"
	@echo "⚠️  Data is kept in /var/lib/openproject (pgdata + assets)"

info:
	@echo "ℹ️  Deployment information:"
	@echo ""
	@echo "Domain:          https://nexus.bestcash.me"
	@echo "Directory:       $(shell pwd)"
	@echo "Variables:       $(shell pwd)/.env"
	@echo "PostgreSQL DB:   built into the container (data: /var/lib/openproject/pgdata)"
	@echo "Assets:          /var/lib/openproject/assets"
	@echo "Traefik:         127.0.0.1:8080 (web) / 127.0.0.1:8081 (dashboard)"
	@echo ""
	@echo "Files:"
	@ls -lh docker-compose.yml .env setup.sh Makefile 2>/dev/null || echo "Missing files"
	@echo ""

version:
	@echo "🔍 Installed versions:"
	@docker --version
	@docker-compose --version
	@nginx -v 2>&1
	@echo ""
	@echo "📊 Services:"
	@sudo systemctl is-active nginx && echo "✅ Nginx active" || echo "❌ Nginx inactive"
	@echo ""
	@echo "SSL certificate:"
	@sudo certbot certificates 2>/dev/null | grep -A 2 "nexus.bestcash.me" || echo "Certificate not found"
