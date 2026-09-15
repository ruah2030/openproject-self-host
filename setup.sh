#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="nexus.bestcash.me"
DATA_DIR="/var/lib/openproject"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   OpenProject (tout-en-un) + Traefik + Nginx — Setup       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Check prerequisites
echo -e "${BLUE}1️⃣  Vérifier les prérequis...${NC}"
command -v docker &> /dev/null || { echo -e "${RED}❌ Docker non installé${NC}"; exit 1; }
docker compose version &> /dev/null || command -v docker-compose &> /dev/null || { echo -e "${RED}❌ Docker Compose non installé${NC}"; exit 1; }
echo -e "${GREEN}✅ Docker${NC}"
echo -e "${GREEN}✅ Docker Compose${NC}"
echo ""

# Compose command (v2 plugin or v1 binary)
if docker compose version &> /dev/null; then
    COMPOSE="docker compose"
else
    COMPOSE="docker-compose"
fi

# Step 2: Create data directories (PostgreSQL + assets persisted on the host)
echo -e "${BLUE}2️⃣  Créer les répertoires de données...${NC}"
sudo mkdir -p "$DATA_DIR/pgdata" "$DATA_DIR/assets"
echo -e "${GREEN}✅ Répertoires créés: $DATA_DIR/{pgdata,assets}${NC}"
echo ""

# Step 3: Create .env file (SECRET_KEY_BASE)
echo -e "${BLUE}3️⃣  Configurer le fichier .env...${NC}"
if [ -f "$PROJECT_DIR/.env" ] && grep -q "^SECRET_KEY_BASE=" "$PROJECT_DIR/.env"; then
    echo -e "${YELLOW}⚠️  .env existe déjà avec une SECRET_KEY_BASE — conservé tel quel.${NC}"
    echo -e "${YELLOW}   (Ne JAMAIS changer la clé d'une installation existante!)${NC}"
else
    SECRET_KEY_BASE=$(openssl rand -hex 64)
    cat > "$PROJECT_DIR/.env" << EOF
# OpenProject Secret Key (Rails sessions & encryption)
# NEVER SHARE THIS! NEVER CHANGE THIS on an existing installation!
SECRET_KEY_BASE=$SECRET_KEY_BASE
EOF
    echo -e "${GREEN}✅ Fichier .env créé avec une nouvelle SECRET_KEY_BASE${NC}"
    echo -e "${YELLOW}   Si vous migrez une installation existante, remplacez la clé${NC}"
    echo -e "${YELLOW}   dans .env par celle de l'ancienne installation AVANT de démarrer.${NC}"
fi
chmod 600 "$PROJECT_DIR/.env"
echo -e "${GREEN}✅ Permissions .env: 600${NC}"
echo ""

# Step 4: Launch Docker Compose
echo -e "${BLUE}4️⃣  Lancer les containers Docker (Traefik + OpenProject)...${NC}"
cd "$PROJECT_DIR"
$COMPOSE up -d
echo -e "${GREEN}✅ Containers lancés${NC}"
echo ""

# Step 5: Show summary
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Installation Terminée!                               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📋 Résumé:${NC}"
echo -e "   Répertoire:     ${BLUE}$PROJECT_DIR${NC}"
echo -e "   Domaine:        ${BLUE}https://$DOMAIN${NC}"
echo -e "   Données:        ${BLUE}$DATA_DIR/pgdata (BD) + $DATA_DIR/assets (fichiers)${NC}"
echo -e "   Traefik:        ${BLUE}127.0.0.1:8080 (web) / 127.0.0.1:8081 (dashboard)${NC}"
echo ""
echo -e "${YELLOW}🔗 Commandes utiles:${NC}"
echo -e "   Voir les logs:     ${BLUE}cd $PROJECT_DIR && $COMPOSE logs -f${NC}"
echo -e "   Arrêter:          ${BLUE}cd $PROJECT_DIR && $COMPOSE down${NC}"
echo -e "   Redémarrer:       ${BLUE}cd $PROJECT_DIR && $COMPOSE restart${NC}"
echo -e "   Avec Make:        ${BLUE}cd $PROJECT_DIR && make help${NC}"
echo ""
echo -e "${YELLOW}⏳ Premier démarrage: OpenProject initialise sa base de données,${NC}"
echo -e "${YELLOW}   comptez plusieurs minutes avant que https://$DOMAIN réponde.${NC}"
echo ""
echo -e "${YELLOW}📊 Containers:${NC}"
docker ps
echo ""
