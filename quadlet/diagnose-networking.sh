#!/bin/bash

# diagnose-networking.sh - Podman Pod Networking Diagnostic Tool
# Diagnoses pod networking for Archon host networking pod deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Functions for different diagnostic sections
print_header() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}🔍 $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"
}

print_section() {
    echo -e "\n${CYAN}── $1 ──${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${MAGENTA}ℹ️  $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should NOT be run as root (rootless Podman diagnostics)"
        exit 1
    fi
}

# System information
collect_system_info() {
    print_header "SYSTEM INFORMATION"

    print_section "Operating System"
    if command -v hostnamectl &> /dev/null; then
        hostnamectl | grep -E "(Operating System|Kernel|Architecture)"
    else
        uname -a
    fi

    print_section "User Context"
    echo "User: $(whoami)"
    echo "UID: $(id -u)"
    echo "GID: $(id -g)"
    echo "Groups: $(id -G)"

    print_section "XDG Directories"
    echo "XDG_RUNTIME_DIR: ${XDG_RUNTIME_DIR:-not set}"
    echo "XDG_CONFIG_HOME: ${XDG_CONFIG_HOME:-not set}"
    echo "HOME: $HOME"
}

# Podman version and configuration
check_podman_config() {
    print_header "PODMAN CONFIGURATION"

    print_section "Podman Version"
    if command -v podman &> /dev/null; then
        podman --version
        print_success "Podman is installed"
    else
        print_error "Podman is not installed"
        return 1
    fi

    print_section "Podman Info"
    podman info --format json | jq -r '
        "Host OS: " + .host.os,
        "Podman Version: " + .version.Version,
        "Network Backend: " + .host.networkBackend,
        "Network Backend Mode: " + (.host.networkBackendInfo.package // "unknown"),
        "Runtime: " + .host.ociRuntime.name,
        "Root: " + (.store.graphRoot // "unknown"),
        "Runroot: " + (.store.runRoot // "unknown")
    '

    print_section "Network Backends Available"
    if podman info --format json | jq -e '.host.networkBackend' &>/dev/null; then
        NETWORK_BACKEND=$(podman info --format json | jq -r '.host.networkBackend')
        echo "Current backend: $NETWORK_BACKEND"

        case $NETWORK_BACKEND in
            "netavark")
                print_success "Using netavark (modern backend)"
                ;;
            "cni")
                print_warning "Using CNI (legacy backend)"
                ;;
            *)
                print_info "Using backend: $NETWORK_BACKEND"
                ;;
        esac
    fi

    print_section "Rootless Configuration"
    if podman info --format json | jq -e '.host.security.rootless' | grep -q true; then
        print_success "Running in rootless mode"

        # Check for pasta vs slirp4netns
        if podman info --format json | jq -e '.host.networkBackendInfo.package' | grep -q pasta; then
            print_info "Using pasta for rootless networking"
            print_warning "pasta networking can cause connection reset issues"
        elif podman info --format json | jq -e '.host.networkBackendInfo.package' | grep -q slirp4netns; then
            print_success "Using slirp4netns for rootless networking"
        fi
    else
        print_error "Not running in rootless mode"
    fi
}

# Check current pod and container status
check_pod_status() {
    print_header "CURRENT POD STATUS"

    print_section "All Pods"
    if podman pod ls --format table 2>/dev/null; then
        echo
    else
        print_info "No pods found"
    fi

    print_section "Archon Pod"
    if podman pod exists "archon.pod" 2>/dev/null; then
        print_success "Pod archon.pod exists"
        echo "Status: $(podman pod inspect archon.pod --format '{{.State}}')"
        echo "Containers: $(podman pod inspect archon.pod --format '{{len .Containers}}')"
        echo "Network Mode: $(podman pod inspect archon.pod --format '{{.InfraConfig.NetworkOptions.Network}}')"

        # Check if using host networking
        if podman pod inspect archon.pod --format '{{.InfraConfig.NetworkOptions.Network}}' | grep -q "host"; then
            print_success "Using host networking (eliminates pasta issues)"
        else
            print_warning "Not using host networking - may experience pasta issues"
        fi
    else
        print_info "Pod archon.pod does not exist"
    fi
    echo
}

# Network connectivity tests
test_network_connectivity() {
    print_header "NETWORK CONNECTIVITY TESTS"

    # Find active Archon services
    local active_services=()
    for service in archon-server archon-frontend archon-mcp; do
        if systemctl --user is-active --quiet "${service}.service" 2>/dev/null; then
            active_services+=("$service")
        fi
    done

    for service in archon-server-standalone archon-frontend-standalone archon-mcp-standalone; do
        if systemctl --user is-active --quiet "${service}.service" 2>/dev/null; then
            active_services+=("$service")
        fi
    done

    if [[ ${#active_services[@]} -eq 0 ]]; then
        print_warning "No active Archon services found for testing"
        return 0
    fi

    print_section "Active Services Found"
    printf '%s\n' "${active_services[@]}"
    echo

    # Test standard ports
    local ports=(3737 8181 8051)
    local port_names=("Frontend" "API Server" "MCP Server")

    for i in "${!ports[@]}"; do
        local port="${ports[$i]}"
        local name="${port_names[$i]}"

        print_section "Testing $name (port $port)"

        # Check if port is bound
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            print_success "Port $port is bound"

            # Show what's binding the port
            local binding_process=$(netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | head -1)
            echo "Bound by: $binding_process"

            # Test connection
            print_info "Testing connection to localhost:$port"
            if timeout 5 bash -c "exec 3<>/dev/tcp/localhost/$port" 2>/dev/null; then
                print_success "TCP connection to port $port successful"
                exec 3>&-

                # Test HTTP if it's a web service
                if [[ $port == 3737 ]] || [[ $port == 8181 ]]; then
                    if timeout 10 curl -s -f "http://localhost:$port/" &>/dev/null; then
                        print_success "HTTP request to port $port successful"
                    else
                        print_error "HTTP request to port $port failed"
                        print_info "Trying with verbose curl..."
                        timeout 10 curl -v "http://localhost:$port/" 2>&1 | head -20
                    fi
                fi
            else
                print_error "TCP connection to port $port failed"

                # Additional diagnostics for pasta networking
                if pgrep -f pasta > /dev/null; then
                    print_warning "pasta process detected - this may be the networking issue"
                    print_info "pasta processes:"
                    pgrep -f pasta | xargs ps -p 2>/dev/null || true
                fi
            fi
        else
            print_error "Port $port is not bound"
        fi
        echo
    done
}

# Check systemd services
check_systemd_services() {
    print_header "SYSTEMD SERVICE STATUS"

    print_section "User Service Status"
    systemctl --user list-units 'archon*' --no-legend --no-pager | while read unit load active sub desc; do
        case $active in
            "active")
                print_success "$unit: $active ($sub)"
                ;;
            "failed")
                print_error "$unit: $active ($sub)"
                ;;
            "inactive")
                print_info "$unit: $active ($sub)"
                ;;
            *)
                print_warning "$unit: $active ($sub)"
                ;;
        esac
    done

    print_section "Failed Services"
    local failed_services=$(systemctl --user list-units --failed 'archon*' --no-legend --no-pager | awk '{print $1}')
    if [[ -n "$failed_services" ]]; then
        echo "$failed_services" | while read service; do
            print_error "Failed service: $service"
            print_info "Last 5 log entries for $service:"
            systemctl --user status "$service" --lines=5 --no-pager || true
        done
    else
        print_success "No failed Archon services"
    fi
}

# Network namespace and process analysis
check_network_namespaces() {
    print_header "NETWORK NAMESPACE ANALYSIS"

    print_section "Network Processes"
    print_info "pasta processes:"
    pgrep -f pasta | xargs ps -f 2>/dev/null || print_info "No pasta processes found"

    print_info "slirp4netns processes:"
    pgrep -f slirp4netns | xargs ps -f 2>/dev/null || print_info "No slirp4netns processes found"

    print_info "podman processes:"
    pgrep -f podman | xargs ps -f 2>/dev/null || print_info "No podman processes found"

    print_section "Network Statistics"
    if command -v ss &> /dev/null; then
        print_info "Listening ports (ss):"
        ss -tlnp | grep -E ':(3737|8181|8051)' || print_info "No Archon ports found listening"
    else
        print_info "Listening ports (netstat):"
        netstat -tlnp | grep -E ':(3737|8181|8051)' || print_info "No Archon ports found listening"
    fi
}

# Configuration file analysis
check_quadlet_config() {
    print_header "QUADLET CONFIGURATION ANALYSIS"

    local quadlet_dir=""
    if [[ -n "$XDG_CONFIG_HOME" ]]; then
        quadlet_dir="$XDG_CONFIG_HOME/containers/systemd"
    else
        quadlet_dir="$HOME/.config/containers/systemd"
    fi

    print_section "Quadlet Directory"
    echo "Looking in: $quadlet_dir"

    if [[ -d "$quadlet_dir" ]]; then
        print_success "Quadlet directory exists"

        print_info "Installed files:"
        find "$quadlet_dir" -name "*.pod" -o -name "*.container" -o -name "*.network" | sort

        # Check for archon-specific files
        local archon_files=$(find "$quadlet_dir" -name "*archon*" | wc -l)
        if [[ $archon_files -gt 0 ]]; then
            print_success "Found $archon_files Archon quadlet files"
        else
            print_warning "No Archon quadlet files found"
        fi
    else
        print_warning "Quadlet directory does not exist"
    fi

    print_section "Source Configuration Files"
    echo "Looking in: $SCRIPT_DIR"

    local config_files=("archon.pod")
    for file in "${config_files[@]}"; do
        if [[ -f "$SCRIPT_DIR/$file" ]]; then
            print_success "Source file exists: $file (host networking)"
        else
            print_warning "Source file missing: $file"
        fi
    done
}

# Recommend fixes
recommend_fixes() {
    print_header "RECOMMENDED FIXES"

    print_section "Immediate Actions"
    echo "1. Use pod mode (host networking):"
    echo "   $SCRIPT_DIR/switch-mode.sh pod --install"
    echo
    echo "2. Fall back to standalone mode for debugging:"
    echo "   $SCRIPT_DIR/switch-mode.sh standalone --install"
    echo

    print_section "System-Level Fixes"
    echo "1. Update Podman to latest version:"
    echo "   sudo dnf update podman"
    echo
    echo "2. Reset Podman networking:"
    echo "   podman system reset --force"
    echo "   (Warning: This will remove all containers and pods)"
    echo


    print_section "Configuration Notes"
    echo "The current pod configuration uses host networking, which:"
    echo "• Eliminates pasta networking issues completely"
    echo "• Provides the best performance and reliability"
    echo "• Is the recommended approach for production deployments"
    echo
}

# Generate comprehensive report
generate_report() {
    print_header "GENERATING DIAGNOSTIC REPORT"

    local report_file="$HOME/archon-networking-report-$(date +%Y%m%d-%H%M%S).txt"

    print_info "Saving comprehensive report to: $report_file"

    {
        echo "Archon Pod Networking Diagnostic Report"
        echo "Generated: $(date)"
        echo "User: $(whoami)"
        echo "Host: $(hostname)"
        echo

        echo "=== SYSTEM INFO ==="
        uname -a
        echo

        echo "=== PODMAN VERSION ==="
        podman --version
        echo

        echo "=== PODMAN INFO ==="
        podman info
        echo

        echo "=== POD STATUS ==="
        podman pod ls
        echo

        echo "=== CONTAINER STATUS ==="
        podman ps -a --pod
        echo

        echo "=== SYSTEMD SERVICES ==="
        systemctl --user list-units 'archon*' --no-pager
        echo

        echo "=== NETWORK CONNECTIONS ==="
        netstat -tlnp 2>/dev/null | grep -E ':(3737|8181|8051)' || echo "No Archon ports listening"
        echo

        echo "=== PROCESSES ==="
        echo "pasta processes:"
        pgrep -f pasta | xargs ps -f 2>/dev/null || echo "None"
        echo "slirp4netns processes:"
        pgrep -f slirp4netns | xargs ps -f 2>/dev/null || echo "None"
        echo

        echo "=== RECENT LOGS ==="
        echo "Pod logs (if exists):"
        journalctl --user -u archon.pod --since "1 hour ago" --no-pager || echo "No pod logs"

    } > "$report_file"

    print_success "Report saved to: $report_file"
}

# Main function
main() {
    local action="${1:-diagnose}"

    case $action in
        diagnose|--diagnose|-d)
            check_root
            collect_system_info
            check_podman_config
            check_pod_status
            check_systemd_services
            test_network_connectivity
            check_network_namespaces
            check_quadlet_config
            recommend_fixes
            ;;
        report|--report|-r)
            check_root
            generate_report
            ;;
        help|--help|-h)
            echo "Archon Pod Networking Diagnostic Tool"
            echo
            echo "Usage: $0 [ACTION]"
            echo
            echo "Actions:"
            echo "  diagnose (default) - Run complete diagnostic"
            echo "  report             - Generate detailed report file"
            echo "  help               - Show this help"
            echo
            ;;
        *)
            print_error "Unknown action: $action"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
