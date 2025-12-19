#!/bin/bash

# test-connectivity.sh - Quick connectivity test for Archon services
# Tests all service endpoints and provides immediate feedback

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Service definitions
declare -A SERVICES=(
    ["Frontend"]="3737:http://localhost:3737"
    ["API Server"]="8181:http://localhost:8181/health"
    ["MCP Server"]="8051:http://localhost:8051/health"
    ["Agents"]="8052:http://localhost:8052/health"
    ["Documentation"]="3838:http://localhost:3838"
)

print_header() {
    echo -e "\n${BLUE}🔍 Archon Service Connectivity Test${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Test a single service endpoint
test_service() {
    local name="$1"
    local port="$2"
    local url="$3"
    local timeout=10

    echo -e "\n${CYAN}Testing $name (port $port)...${NC}"

    # Check if port is listening
    if ! netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        print_error "$name: Port $port is not listening"
        return 1
    fi

    print_info "Port $port is bound"

    # Test TCP connection
    if ! timeout 5 bash -c "exec 3<>/dev/tcp/localhost/$port" 2>/dev/null; then
        print_error "$name: TCP connection failed"
        return 1
    fi
    exec 3>&-
    print_info "TCP connection successful"

    # Test HTTP endpoint if it's a web service
    if [[ "$url" == http* ]]; then
        local http_code
        http_code=$(timeout $timeout curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")

        case "$http_code" in
            200|201|202|204)
                print_success "$name: HTTP $http_code - Service is healthy"
                return 0
                ;;
            404|405)
                print_warning "$name: HTTP $http_code - Service responding but endpoint may not exist"
                return 0
                ;;
            000)
                print_error "$name: HTTP connection failed (timeout or connection refused)"
                return 1
                ;;
            *)
                print_error "$name: HTTP $http_code - Service error"
                return 1
                ;;
        esac
    else
        print_success "$name: TCP connection successful"
        return 0
    fi
}

# Test all services
test_all_services() {
    print_header

    local total=0
    local passed=0
    local failed=0

    for service_name in "${!SERVICES[@]}"; do
        local service_info="${SERVICES[$service_name]}"
        local port="${service_info%:*}"
        local url="${service_info#*:}"

        total=$((total + 1))

        if test_service "$service_name" "$port" "$url"; then
            passed=$((passed + 1))
        else
            failed=$((failed + 1))
        fi
    done

    # Summary
    echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}Test Summary:${NC}"
    echo -e "  Total services: $total"
    echo -e "  ${GREEN}Passed: $passed${NC}"
    echo -e "  ${RED}Failed: $failed${NC}"

    if [[ $failed -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 All services are healthy!${NC}"
        return 0
    else
        echo -e "\n${RED}💥 $failed service(s) have connectivity issues${NC}"
        return 1
    fi
}

# Show current deployment mode
show_deployment_mode() {
    echo -e "\n${CYAN}Current Deployment Mode:${NC}"

    if systemctl --user is-active --quiet archon.pod 2>/dev/null; then
        echo -e "  ${GREEN}●${NC} Pod mode (host networking)"
    elif systemctl --user is-active --quiet archon-server-standalone.service 2>/dev/null; then
        echo -e "  ${GREEN}●${NC} Standalone mode"
    else
        echo -e "  ${YELLOW}●${NC} No active Archon deployment detected"
    fi
}

# Provide troubleshooting recommendations
show_troubleshooting() {
    echo -e "\n${YELLOW}🔧 Troubleshooting Commands:${NC}"
    echo
    echo -e "${CYAN}Check service status:${NC}"
    echo "  ./switch-mode.sh status"
    echo
    echo -e "${CYAN}Run diagnostics:${NC}"
    echo "  ./diagnose-networking.sh"
    echo
    echo -e "${CYAN}Try different modes:${NC}"
    echo "  ./switch-mode.sh pod --install         # Pod with host networking (recommended)"
    echo "  ./switch-mode.sh standalone --install  # Individual containers (debugging)"
    echo
    echo -e "${CYAN}Manual testing:${NC}"
    echo "  curl -v http://localhost:3737          # Frontend"
    echo "  curl -v http://localhost:8181/health   # API"
    echo "  curl -v http://localhost:8051/health   # MCP"
}

# Quick mode - test only essential services
test_quick() {
    print_header
    echo -e "${CYAN}Quick Test Mode - Essential Services Only${NC}\n"

    local quick_services=("Frontend" "API Server" "MCP Server")
    local passed=0
    local failed=0

    for service_name in "${quick_services[@]}"; do
        if [[ -n "${SERVICES[$service_name]}" ]]; then
            local service_info="${SERVICES[$service_name]}"
            local port="${service_info%:*}"
            local url="${service_info#*:}"

            if test_service "$service_name" "$port" "$url"; then
                passed=$((passed + 1))
            else
                failed=$((failed + 1))
            fi
        fi
    done

    echo -e "\n${CYAN}Quick Test Summary: ${GREEN}$passed passed${NC}, ${RED}$failed failed${NC}"

    if [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}✅ Core services are working!${NC}"
        return 0
    else
        return 1
    fi
}

# Show usage information
show_usage() {
    echo "Archon Service Connectivity Test"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --quick, -q    Test only essential services (Frontend, API, MCP)"
    echo "  --mode, -m     Show current deployment mode"
    echo "  --help, -h     Show this help message"
    echo
    echo "Examples:"
    echo "  $0             # Test all services"
    echo "  $0 --quick     # Test essential services only"
    echo "  $0 --mode      # Show deployment mode"
    echo
}

# Main function
main() {
    local mode="full"

    # Parse arguments
    case "${1:-}" in
        --quick|-q)
            mode="quick"
            ;;
        --mode|-m)
            show_deployment_mode
            return 0
            ;;
        --help|-h)
            show_usage
            return 0
            ;;
        "")
            mode="full"
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_usage
            return 1
            ;;
    esac

    # Show deployment mode first
    show_deployment_mode

    # Run tests
    local test_result=0
    if [[ "$mode" == "quick" ]]; then
        test_quick || test_result=1
    else
        test_all_services || test_result=1
    fi

    # Show troubleshooting if tests failed
    if [[ $test_result -ne 0 ]]; then
        show_troubleshooting
    fi

    return $test_result
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
