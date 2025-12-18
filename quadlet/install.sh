#!/bin/bash

# install.sh - Install Archon quadlet files for rootless systemctl
# This script copies quadlet files to the appropriate systemd user directories

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory and project root
export SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export PROJ_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export PROJ_PATH="${PROJ_ROOT/#$HOME/%h}"
export ENV_PATH_DEFAULT="${PROJ_PATH}/quadlet/env.defaults"
export ENV_PATH="${PROJ_PATH}/.env"

echo -e "${BLUE}🚀 Archon Quadlet Installer${NC}"
echo "Installing quadlet files for rootless systemctl..."
echo

# Determine the best installation directory
if [[ -n "$XDG_CONFIG_HOME" ]]; then
    QUADLET_DIR="$XDG_CONFIG_HOME/containers/systemd"
    LOCATION_TYPE="config"
else
    QUADLET_DIR="$HOME/.config/containers/systemd"
    LOCATION_TYPE="config"
fi

echo -e "📁 Target directory: ${YELLOW}$QUADLET_DIR${NC} ($LOCATION_TYPE)"
echo

# Create target directory if it doesn't exist
if [[ ! -d "$QUADLET_DIR" ]]; then
    echo -e "📂 Creating directory: $QUADLET_DIR"
    mkdir -p "$QUADLET_DIR"
fi

# List of quadlet files to install
QUADLET_FILES=(
    "archon.pod"
    "archon-network.network"
    "archon-server.build"
    "archon-server.container"
    "archon-server-src.volume"
    "archon-server-tests.volume"
    "archon-server-migration.volume"
    "archon-frontend.build"
    "archon-frontend.container"
    "archon-frontend-src.volume"
    "archon-frontend-public.volume"
    "archon-mcp.build"
    "archon-mcp.container"
    "archon-agents.build"
    "archon-agents.container"
    "archon-docs.build"
    "archon-docs.container"
)

# Function to resolve environment variables
update_env() {
    local file="$1"
    local target_file="$QUADLET_DIR/$file"
    envsubst < "$SCRIPT_DIR/$file" > "$target_file"
}

# Install quadlet files
echo -e "${BLUE}📋 Installing quadlet files:${NC}"
installed_count=0
for file in "${QUADLET_FILES[@]}"; do
    if [[ -f "$SCRIPT_DIR/$file" ]]; then
        echo -e "  📄 Installing: ${GREEN}$file${NC}"
        update_env "$file"
        installed_count=$((installed_count + 1))
    else
        echo -e "  ⚠️  Warning: ${YELLOW}$file not found, skipping${NC}"
    fi
done

echo
echo -e "${GREEN}✅ Installed $installed_count quadlet files${NC}"

# Check for environment file
echo
echo -e "${BLUE}🔧 Environment Setup:${NC}"
if [[ ! -f "$PROJ_ROOT/.env" ]]; then
    echo -e "  ❌ Environment file not found: ${RED}$PROJ_ROOT/.env${NC}"
    echo -e "  📝 To create it:"
    echo -e "     ${YELLOW}cp $PROJ_ROOT/.env.example $PROJ_ROOT/.env${NC}"
    echo -e "     ${YELLOW}# Edit $PROJ_ROOT/.env with your actual values${NC}"
    ENV_MISSING=true
else
    echo -e "  ✅ Environment file exists: ${GREEN}$PROJ_ROOT/.env${NC}"
    ENV_MISSING=false
fi

# Reload systemd user daemon
echo
echo -e "${BLUE}🔄 Reloading systemd user daemon...${NC}"
if systemctl --user daemon-reload; then
    echo -e "  ✅ ${GREEN}Systemd user daemon reloaded${NC}"
else
    echo -e "  ❌ ${RED}Failed to reload systemd daemon${NC}"
    exit 1
fi

# List available services
echo
echo -e "${BLUE}📋 Available services:${NC}"
echo

# Core services
echo -e "${GREEN}Core Services:${NC}"
echo "  • archon-server.service    - FastAPI backend"
echo "  • archon-frontend.service  - React UI"
echo "  • archon-mcp.service       - Model Context Protocol server"
echo

# Optional services
echo -e "${YELLOW}Optional Services:${NC}"
echo "  • archon-agents.service    - AI agents (requires AGENTS_ENABLED=true)"
echo "  • archon-docs.service      - Documentation site"
echo

# Build services
echo -e "${BLUE}Build Services:${NC}"
echo "  • archon-server.build      - Build server image"
echo "  • archon-frontend.build    - Build frontend image"
echo "  • archon-mcp.build         - Build MCP server image"
echo "  • archon-agents.build      - Build agents image"
echo "  • archon-docs.build        - Build docs image"
echo

# Usage instructions
echo -e "${BLUE}🎯 Usage Instructions:${NC}"
echo

if [[ "$ENV_MISSING" == true ]]; then
    echo -e "${YELLOW}1. First, set up your environment:${NC}"
    echo "   cp $PROJ_ROOT/.env.example $PROJ_ROOT/.env"
    echo "   # Edit $PROJ_ROOT/.env with your Supabase credentials"
    echo
fi

echo -e "${GREEN}$(if [[ "$ENV_MISSING" == true ]]; then echo "2."; else echo "1."; fi) Build images:${NC}"
echo "   systemctl --user start archon-server.build"
echo "   systemctl --user start archon-frontend.build"
echo "   systemctl --user start archon-mcp.build"
echo "   # Optional:"
echo "   systemctl --user start archon-agents.build"
echo "   systemctl --user start archon-docs.build"
echo

echo -e "${GREEN}$(if [[ "$ENV_MISSING" == true ]]; then echo "3."; else echo "2."; fi) Start services:${NC}"
echo "   systemctl --user start archon-server.service"
echo "   systemctl --user start archon-frontend.service"
echo "   systemctl --user start archon-mcp.service"
echo "   # Optional:"
echo "   systemctl --user start archon-docs.service"
echo

echo -e "${BLUE}📊 Monitoring:${NC}"
echo "   systemctl --user status archon-server.service"
echo "   journalctl --user -u archon-server.service -f"
echo "   systemctl --user list-units 'archon-*'"
echo

# Service URLs
echo -e "${BLUE}🌐 Service URLs (default ports):${NC}"
echo "   • Frontend:      http://localhost:3737"
echo "   • API Server:    http://localhost:8181"
echo "   • MCP Server:    http://localhost:8051"
echo "   • Agents:        http://localhost:8052"
echo "   • Documentation: http://localhost:3838"
echo

if [[ "$ENV_MISSING" == true ]]; then
    echo -e "${YELLOW}⚠️  Remember to configure your .env file before starting services!${NC}"
else
    echo -e "${GREEN}🎉 Installation complete! You can now start building and running services.${NC}"
fi

echo
echo -e "${BLUE}💡 Tip:${NC} Use 'systemctl --user enable <service>' to start services on boot"
