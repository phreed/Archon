#!/bin/bash

# switch-mode.sh - Switch between pod and standalone deployment modes
# Usage: ./switch-mode.sh [pod|standalone] [--install]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory and project root
export SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export PROJ_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export PROJ_PATH="${PROJ_ROOT/#$HOME/%h}"
export ENV_PATH_DEFAULT="${PROJ_PATH}/quadlet/env.defaults"
export ENV_PATH="${PROJ_PATH}/.env"

# Current mode detection
CURRENT_MODE="unknown"
if systemctl --user is-active --quiet archon.pod 2>/dev/null; then
    CURRENT_MODE="pod"
elif systemctl --user is-active --quiet archon-server-standalone.service 2>/dev/null; then
    CURRENT_MODE="standalone"
fi

# Help function
show_help() {
    echo -e "${BLUE}🔄 Archon Deployment Mode Switcher${NC}"
    echo
    echo "Switch between pod-based and standalone container deployments"
    echo
    echo -e "${CYAN}Usage:${NC}"
    echo "  $0 [MODE] [OPTIONS]"
    echo
    echo -e "${CYAN}Modes:${NC}"
    echo "  pod        - Deploy services in a shared pod (recommended for production)"
    echo "  standalone - Deploy services as individual containers (easier debugging)"
    echo "  status     - Show current deployment mode and service status"
    echo
    echo -e "${CYAN}Options:${NC}"
    echo "  --install  - Install quadlet files to systemd directory"
    echo "  --help     - Show this help message"
    echo
    echo -e "${CYAN}Examples:${NC}"
    echo "  $0 standalone          # Switch to standalone mode"
    echo "  $0 pod --install       # Switch to pod mode and install files"
    echo "  $0 status              # Check current mode"
    echo
}

# Function to stop all archon services
stop_all_services() {
    echo -e "${YELLOW}🛑 Stopping all Archon services...${NC}"

    # Stop standalone services
    for service in archon-server-standalone archon-frontend-standalone archon-mcp-standalone archon-agents-standalone archon-docs-standalone; do
        if systemctl --user is-active --quiet ${service}.service 2>/dev/null; then
            echo -e "  Stopping ${service}.service"
            systemctl --user stop ${service}.service || true
        fi
    done

    # Stop pod services
    for service in archon-server archon-frontend archon-mcp archon-agents archon-docs; do
        if systemctl --user is-active --quiet ${service}.service 2>/dev/null; then
            echo -e "  Stopping ${service}.service"
            systemctl --user stop ${service}.service || true
        fi
    done

    # Stop pod
    if systemctl --user is-active --quiet archon.pod 2>/dev/null; then
        echo -e "  Stopping archon.pod"
        systemctl --user stop archon.pod || true
    fi

    echo -e "${GREEN}✅ All services stopped${NC}"
}

# Function to show current status
show_status() {
    echo -e "${BLUE}📊 Current Deployment Status${NC}"
    echo
    echo -e "${CYAN}Mode:${NC} $CURRENT_MODE"
    echo

    if [[ "$CURRENT_MODE" == "pod" ]]; then
        echo -e "${CYAN}Pod Services:${NC}"
        systemctl --user list-units 'archon*.service' --no-legend --no-pager | while read unit load active sub desc; do
            if [[ "$active" == "active" ]]; then
                status_color="$GREEN"
            elif [[ "$active" == "failed" ]]; then
                status_color="$RED"
            else
                status_color="$YELLOW"
            fi
            echo -e "  ${status_color}●${NC} $unit ($active)"
        done

        if systemctl --user is-active --quiet archon.pod 2>/dev/null; then
            echo -e "\n${CYAN}Pod Status:${NC}"
            echo -e "  ${GREEN}●${NC} archon.pod (active)"
            echo
            echo -e "${CYAN}Published Ports:${NC}"
            echo "  • Frontend:      http://localhost:3737"
            echo "  • API Server:    http://localhost:8181"
            echo "  • MCP Server:    http://localhost:8051"
        fi

    elif [[ "$CURRENT_MODE" == "standalone" ]]; then
        echo -e "${CYAN}Standalone Services:${NC}"
        systemctl --user list-units 'archon*-standalone.service' --no-legend --no-pager | while read unit load active sub desc; do
            if [[ "$active" == "active" ]]; then
                status_color="$GREEN"
            elif [[ "$active" == "failed" ]]; then
                status_color="$RED"
            else
                status_color="$YELLOW"
            fi
            echo -e "  ${status_color}●${NC} $unit ($active)"
        done

        echo
        echo -e "${CYAN}Published Ports:${NC}"
        echo "  • Frontend:      http://localhost:3737"
        echo "  • API Server:    http://localhost:8181"
        echo "  • MCP Server:    http://localhost:8051"
        echo "  • Agents:        http://localhost:8052"
        echo "  • Documentation: http://localhost:3838"

    else
        echo -e "${YELLOW}No Archon services are currently running${NC}"
    fi

    echo
    echo -e "${CYAN}Available Images:${NC}"
    podman images | grep -E "(archon|localhost)" | head -5
}

# Function to install quadlet files
install_quadlet_files() {
    local mode=$1

    # Determine the installation directory
    if [[ -n "$XDG_CONFIG_HOME" ]]; then
        QUADLET_DIR="$XDG_CONFIG_HOME/containers/systemd/archon"
    else
        QUADLET_DIR="$HOME/.config/containers/systemd/archon"
    fi

    echo -e "${BLUE}📁 Installing quadlet files to: ${YELLOW}$QUADLET_DIR${NC}"

    # Create target directory if it doesn't exist
    mkdir -p "$QUADLET_DIR"

    # Function to resolve environment variables
    update_env() {
        local file="$1"
        local source_file="$2"
        local target_file="$QUADLET_DIR/$file"
        envsubst < "$source_file" > "$target_file"
    }

    # Always install shared components
    echo -e "  📄 Installing shared components..."
    update_env "archon-network.network" "$SCRIPT_DIR/archon-network.network"

    # Install volume files
    for volume in archon-frontend-public archon-frontend-src archon-server-migration archon-server-src archon-server-tests; do
        update_env "${volume}.volume" "$SCRIPT_DIR/${volume}.volume"
    done

    # Install build files
    for build in archon-agents archon-server archon-mcp archon-frontend archon-docs; do
        update_env "${build}.build" "$SCRIPT_DIR/${build}.build"
    done

    if [[ "$mode" == "pod" ]]; then
        echo -e "  📄 Installing pod configuration..."
        update_env "archon.pod" "$SCRIPT_DIR/archon.pod"

        # Install pod-based container files
        for container in archon-server archon-frontend archon-mcp archon-agents archon-docs; do
            update_env "${container}.container" "$SCRIPT_DIR/${container}.container"
        done

    elif [[ "$mode" == "standalone" ]]; then
        echo -e "  📄 Installing standalone configuration..."

        # Install standalone container files
        for container in archon-server-standalone archon-frontend-standalone archon-mcp-standalone archon-agents-standalone archon-docs-standalone; do
            update_env "${container}.container" "$SCRIPT_DIR/standalone/${container}.container"
        done
    fi

    # Copy environment file
    update_env "env.defaults" "$SCRIPT_DIR/env.defaults"

    echo -e "${GREEN}✅ Quadlet files installed for $mode mode${NC}"
}

# Function to switch to pod mode
switch_to_pod() {
    local install_files=$1

    echo -e "${BLUE}🚀 Switching to Pod Mode${NC}"
    echo

    stop_all_services

    if [[ "$install_files" == "true" ]]; then
        install_quadlet_files "pod"
        systemctl --user daemon-reload
    fi

    echo -e "${YELLOW}📋 Starting pod-based services...${NC}"
    systemctl --user start archon-network-network.service
    systemctl --user start archon.pod
    systemctl --user start archon-server.service
    systemctl --user start archon-frontend.service
    systemctl --user start archon-mcp.service

    echo
    echo -e "${GREEN}✅ Switched to pod mode${NC}"
    echo -e "${CYAN}💡 Note:${NC} Pod networking may have connection issues on some systems"
    echo -e "${CYAN}📝 Services:${NC}"
    echo "  • Pod:           archon.pod"
    echo "  • Backend:       archon-server.service"
    echo "  • Frontend:      archon-frontend.service"
    echo "  • MCP:           archon-mcp.service"
    echo
    echo -e "${CYAN}🌐 URLs:${NC}"
    echo "  • Frontend:      http://localhost:3737"
    echo "  • API:           http://localhost:8181"
    echo "  • MCP:           http://localhost:8051"
}

# Function to switch to standalone mode
switch_to_standalone() {
    local install_files=$1

    echo -e "${BLUE}🚀 Switching to Standalone Mode${NC}"
    echo

    stop_all_services

    if [[ "$install_files" == "true" ]]; then
        install_quadlet_files "standalone"
        systemctl --user daemon-reload
    fi

    echo -e "${YELLOW}📋 Starting standalone services...${NC}"
    systemctl --user start archon-network-network.service
    systemctl --user start archon-server-standalone.service
    systemctl --user start archon-frontend-standalone.service
    systemctl --user start archon-mcp-standalone.service

    echo
    echo -e "${GREEN}✅ Switched to standalone mode${NC}"
    echo -e "${CYAN}💡 Note:${NC} Individual containers with direct port publishing"
    echo -e "${CYAN}📝 Services:${NC}"
    echo "  • Backend:       archon-server-standalone.service"
    echo "  • Frontend:      archon-frontend-standalone.service"
    echo "  • MCP:           archon-mcp-standalone.service"
    echo
    echo -e "${CYAN}🌐 URLs:${NC}"
    echo "  • Frontend:      http://localhost:3737"
    echo "  • API:           http://localhost:8181"
    echo "  • MCP:           http://localhost:8051"
}

# Main script logic
main() {
    local mode=""
    local install_files="false"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            pod|standalone|status)
                mode="$1"
                shift
                ;;
            --install)
                install_files="true"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                echo
                show_help
                exit 1
                ;;
        esac
    done

    # Show help if no mode specified
    if [[ -z "$mode" ]]; then
        show_help
        exit 1
    fi

    # Execute based on mode
    case $mode in
        pod)
            switch_to_pod "$install_files"
            ;;
        standalone)
            switch_to_standalone "$install_files"
            ;;
        status)
            show_status
            ;;
        *)
            echo -e "${RED}❌ Invalid mode: $mode${NC}"
            show_help
            exit 1
            ;;
    esac
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
