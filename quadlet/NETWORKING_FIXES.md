# Archon Pod Networking - Simple Solution

Quick setup guide for reliable Podman pod networking using host networking mode.

## TL;DR - The Solution

```bash
# The complete fix for pod networking issues:
./switch-mode.sh pod --install
```

## The Problem

Podman's `pasta` network handler in rootless mode causes "Connection reset by peer" errors when accessing published ports from the host, even though individual containers work perfectly.

**Symptoms:**
- Services start successfully and show healthy status
- Ports are bound correctly (visible in `netstat`)
- External connections to published ports fail immediately
- Affects HTTP, TCP, and all network protocols

## The Solution: Host Networking Pod

**Our pod configuration uses host networking to completely bypass pasta networking.**

```bash
# Switch to pod mode (host networking)
./switch-mode.sh pod --install

# Verify it's working
curl http://localhost:3737  # Should work immediately
```

**Why This Works:**
- ✅ Eliminates pasta networking issues completely
- ✅ Best performance (no network translation)
- ✅ Production-ready and reliable
- ✅ Same functionality as standalone mode but in a pod structure

**Trade-offs:**
- ⚠️ Containers share host network namespace
- ⚠️ Port conflicts possible if running multiple instances

## Alternative: Standalone Mode

**For development and debugging, standalone mode is available:**

```bash
# Fall back to standalone mode (always works)
./switch-mode.sh standalone --install
```

**Benefits:**
- ✅ Always works (proven solution)
- ✅ Easy to debug individual services
- ✅ No pod networking complexity

**When to Use:**
- Development and debugging
- When you need to run multiple instances
- If you prefer individual service management

## Diagnostics and Testing

### Quick Status Check

```bash
# Check current deployment mode and service status
./switch-mode.sh status
```

### Test All Services

```bash
# Quick connectivity test
./test-connectivity.sh --quick

# Full system test
./test-connectivity.sh
```

### Manual Testing

```bash
# Test all services manually
curl -f http://localhost:3737/          # Frontend
curl -f http://localhost:8181/health    # API Server
curl -f http://localhost:8051/health    # MCP Server (if available)

# Check port bindings
netstat -tlnp | grep -E ':(3737|8181|8051)'
```

### Full Diagnostics

```bash
# Run comprehensive diagnostics
./diagnose-networking.sh

# Generate detailed report
./diagnose-networking.sh report
```

## Switching Between Modes

### Pod Mode (Host Networking) - Recommended

```bash
./switch-mode.sh pod --install
```

- Best for production deployments
- Maximum reliability and performance
- Eliminates all pasta networking issues

### Standalone Mode - Development

```bash
./switch-mode.sh standalone --install
```

- Best for development and debugging
- Individual service management
- Always reliable fallback

### Check Current Mode

```bash
./switch-mode.sh status
```

## Understanding the Fix

The solution works by using **host networking** in the pod configuration:

```ini
[Pod]
PodName=archon.pod
# Use host networking to bypass pasta networking issues completely
Network=host
```

This approach:
1. **Bypasses pasta completely** - containers bind directly to host ports
2. **Eliminates network translation** - no intermediate networking layer
3. **Provides maximum compatibility** - works on all systems
4. **Maintains pod structure** - services still run in a coordinated pod

## Production Recommendations

### For Stable Deployments
- Use **pod mode** for best reliability and performance
- Monitor with `./switch-mode.sh status` regularly
- Keep diagnostic tools available for troubleshooting

### For Development
- Use **standalone mode** for easier debugging
- Switch to pod mode for production testing
- Use diagnostic tools to understand any issues

### For CI/CD
- Use **pod mode** for production-like testing
- Use **standalone mode** for parallel testing
- Have mode switching in deployment scripts

## Getting Help

### Check Current Status
```bash
./switch-mode.sh status
```

### Test Connectivity
```bash
./test-connectivity.sh --quick
```

### Run Diagnostics
```bash
./diagnose-networking.sh
```

### Switch Modes
```bash
./switch-mode.sh [pod|standalone] --install
```

### Generate Support Report
```bash
./diagnose-networking.sh report
# Creates timestamped report in home directory
```

## Service URLs

Default URLs when services are running:

| Service | URL | Purpose |
|---------|-----|---------|
| Frontend | http://localhost:3737 | Main user interface |
| API Server | http://localhost:8181 | Backend API endpoints |
| API Health | http://localhost:8181/health | Health check endpoint |
| MCP Server | http://localhost:8051 | Model Context Protocol |
| MCP Health | http://localhost:8051/health | MCP health check |

## Troubleshooting

### "Connection reset by peer"
```bash
# This should not happen with host networking, but if it does:
./switch-mode.sh pod --install
```

### Services won't start
```bash
# Check logs
journalctl --user -u archon-server.service -n 20

# Run diagnostics
./diagnose-networking.sh
```

### Port conflicts
```bash
# Stop all services and restart
./switch-mode.sh pod --install
```

### Can't access services
```bash
# Test each service
./test-connectivity.sh --quick

# Check if services are running
./switch-mode.sh status
```

---

**Status**: ✅ Reliable solution implemented  
**Recommended**: Use pod mode (host networking) for all deployments  
**Updated**: December 19, 2025