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
echo -e "${BLUE}║   OpenProject (all-in-one) + Traefik + Nginx — Setup       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Check prerequisites
echo -e "${BLUE}1️⃣  Checking prerequisites...${NC}"
command -v docker &> /dev/null || { echo -e "${RED}❌ Docker is not installed${NC}"; exit 1; }
docker compose version &> /dev/null || command -v docker-compose &> /dev/null || { echo -e "${RED}❌ Docker Compose is not installed${NC}"; exit 1; }
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
echo -e "${BLUE}2️⃣  Creating data directories...${NC}"
sudo mkdir -p "$DATA_DIR/pgdata" "$DATA_DIR/assets"
echo -e "${GREEN}✅ Directories created: $DATA_DIR/{pgdata,assets}${NC}"
echo ""

# Step 3: Create .env file (SECRET_KEY_BASE)
echo -e "${BLUE}3️⃣  Configuring the .env file...${NC}"
if [ -f "$PROJECT_DIR/.env" ] && grep -q "^SECRET_KEY_BASE=" "$PROJECT_DIR/.env"; then
    echo -e "${YELLOW}⚠️  .env already exists with a SECRET_KEY_BASE — kept as is.${NC}"
    echo -e "${YELLOW}   (NEVER change the key of an existing installation!)${NC}"
else
    SECRET_KEY_BASE=$(openssl rand -hex 64)
    cat > "$PROJECT_DIR/.env" << EOF
# OpenProject Secret Key (Rails sessions & encryption)
# NEVER SHARE THIS! NEVER CHANGE THIS on an existing installation!
SECRET_KEY_BASE=$SECRET_KEY_BASE
EOF
    echo -e "${GREEN}✅ .env file created with a new SECRET_KEY_BASE${NC}"
    echo -e "${YELLOW}   If you are migrating an existing installation, replace the key${NC}"
    echo -e "${YELLOW}   in .env with the old installation key BEFORE starting.${NC}"
fi
chmod 600 "$PROJECT_DIR/.env"
echo -e "${GREEN}✅ .env permissions: 600${NC}"
echo ""

# Step 4: Launch Docker Compose
echo -e "${BLUE}4️⃣  Starting Docker containers (Traefik + OpenProject)...${NC}"
cd "$PROJECT_DIR"
$COMPOSE up -d
echo -e "${GREEN}✅ Containers started${NC}"
echo ""

# Step 5: Show summary
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Installation Complete!                               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📋 Summary:${NC}"
echo -e "   Directory:      ${BLUE}$PROJECT_DIR${NC}"
echo -e "   Domain:         ${BLUE}https://$DOMAIN${NC}"
echo -e "   Data:           ${BLUE}$DATA_DIR/pgdata (DB) + $DATA_DIR/assets (files)${NC}"
echo -e "   Traefik:        ${BLUE}127.0.0.1:8080 (web) / 127.0.0.1:8081 (dashboard)${NC}"
echo ""
echo -e "${YELLOW}🔗 Useful commands:${NC}"
echo -e "   View logs:         ${BLUE}cd $PROJECT_DIR && $COMPOSE logs -f${NC}"
echo -e "   Stop:             ${BLUE}cd $PROJECT_DIR && $COMPOSE down${NC}"
echo -e "   Restart:          ${BLUE}cd $PROJECT_DIR && $COMPOSE restart${NC}"
echo -e "   With Make:        ${BLUE}cd $PROJECT_DIR && make help${NC}"
echo ""
echo -e "${YELLOW}⏳ First start: OpenProject is initializing its database,${NC}"
echo -e "${YELLOW}   allow several minutes before https://$DOMAIN responds.${NC}"
echo ""
echo -e "${YELLOW}📊 Containers:${NC}"
docker ps
echo ""
