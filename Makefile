.PHONY: help install start stop restart logs logs-all status clean nginx-reload ps db shell-openproject shell-traefik backup info version

help:
	@echo "╔════════════════════════════════════════════════════════════╗"
	@echo "║         OpenProject Deployment - Commandes Rapides         ║"
	@echo "╚════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📦 Installation:"
	@echo "   make install          - Installation complète (setup.sh)"
	@echo ""
	@echo "🚀 Gestion des services:"
	@echo "   make start            - Démarrer les containers"
	@echo "   make stop             - Arrêter les containers"
	@echo "   make restart          - Redémarrer les containers"
	@echo "   make status           - Voir le statut des services"
	@echo "   make logs             - Afficher les logs en direct"
	@echo "   make logs-all         - Logs de tous les containers"
	@echo ""
	@echo "🐳 Docker:"
	@echo "   make ps               - Lister les containers"
	@echo "   make shell-openproject- Shell dans OpenProject"
	@echo "   make shell-traefik    - Shell dans Traefik"
	@echo ""
	@echo "💾 Base de données (PostgreSQL intégré au container):"
	@echo "   make db               - Accéder à PostgreSQL"
	@echo "   make backup           - Sauvegarder la base de données"
	@echo ""
	@echo "📊 Information:"
	@echo "   make info             - Informations du déploiement"
	@echo "   make version          - Versions installées"
	@echo ""
	@echo "🧹 Maintenance:"
	@echo "   make clean            - Supprimer tous les containers"
	@echo ""

install:
	@echo "🚀 Lancement de l'installation..."
	@bash setup.sh

start:
	@echo "▶️  Démarrage des services..."
	docker-compose up -d
	@echo "✅ Services démarrés"
	@make status

stop:
	@echo "⏹️  Arrêt des services..."
	docker-compose down
	@echo "✅ Services arrêtés"

restart:
	@echo "🔄 Redémarrage des services..."
	docker-compose restart
	@echo "✅ Services redémarrés"
	@make status

status:
	@echo ""
	@echo "📊 Statut des containers Docker:"
	docker-compose ps
	@echo ""
	@echo "📊 Statut de Nginx:"
	@sudo systemctl status nginx --no-pager 2>/dev/null || echo "Nginx status unavailable"
	@echo ""

logs:
	@echo "📋 Logs OpenProject (Ctrl+C pour arrêter):"
	docker-compose logs -f openproject

logs-all:
	@echo "📋 Logs de tous les containers (Ctrl+C pour arrêter):"
	docker-compose logs -f

nginx-reload:
	@echo "🔄 Rechargement de Nginx..."
	@sudo nginx -t && sudo systemctl reload nginx
	@echo "✅ Nginx rechargé"

ps:
	@echo "🐳 Containers Docker actifs:"
	docker ps
	@echo ""
	@echo "Tous les containers:"
	docker ps -a

shell-openproject:
	@echo "🐚 Accès au shell OpenProject..."
	docker-compose exec openproject bash

shell-traefik:
	@echo "🐚 Accès au shell Traefik..."
	docker-compose exec traefik sh

db:
	@echo "💾 Connexion à PostgreSQL (intégré au container OpenProject)..."
	docker-compose exec openproject su postgres -c "psql openproject"

backup:
	@echo "💾 Sauvegarde de la base de données PostgreSQL..."
	@mkdir -p ./backups
	docker-compose exec -T openproject su postgres -c "pg_dump openproject" > ./backups/openproject_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "✅ Sauvegarde créée dans ./backups/"
	@ls -lh ./backups/

clean:
	@echo "🧹 Suppression de tous les containers..."
	docker-compose down -v
	@echo "✅ Containers supprimés"
	@echo "⚠️  Les données restent dans /var/lib/openproject (pgdata + assets)"

info:
	@echo "ℹ️  Informations du déploiement:"
	@echo ""
	@echo "Domaine:         https://nexus.bestcash.me"
	@echo "Répertoire:      $(shell pwd)"
	@echo "Variables:       $(shell pwd)/.env"
	@echo "BD PostgreSQL:   intégrée au container (données: /var/lib/openproject/pgdata)"
	@echo "Assets:          /var/lib/openproject/assets"
	@echo "Traefik:         127.0.0.1:8080 (web) / 127.0.0.1:8081 (dashboard)"
	@echo ""
	@echo "Fichiers:"
	@ls -lh docker-compose.yml .env setup.sh Makefile 2>/dev/null || echo "Fichiers manquants"
	@echo ""

version:
	@echo "🔍 Versions installées:"
	@docker --version
	@docker-compose --version
	@nginx -v 2>&1
	@echo ""
	@echo "📊 Services:"
	@sudo systemctl is-active nginx && echo "✅ Nginx actif" || echo "❌ Nginx inactif"
	@echo ""
	@echo "Certificat SSL:"
	@sudo certbot certificates 2>/dev/null | grep -A 2 "nexus.bestcash.me" || echo "Certificat non trouvé"
