# Archon Deployment Modes

This document explains the two deployment modes available for Archon services and how to switch between them.

## Overview

Archon supports two deployment architectures:

1. **Pod Mode** (Option 1) - Services run in a shared Podman pod
2. **Standalone Mode** (Option 2) - Services run as individual containers

## Mode Comparison

| Feature | Pod Mode | Standalone Mode |
|---------|----------|-----------------|
| **Networking** | Shared pod network | Individual container networks |
| **Port Publishing** | Pod-level port publishing | Container-level port publishing |
| **Service Discovery** | Automatic within pod | Network-based service discovery |
| **Resource Sharing** | Shared resources within pod | Isolated resources per container |
| **Debugging** | More complex (pod + containers) | Easier (individual containers) |
| **Production Ready** | Yes (when working) | Yes |
| **Known Issues** | Connection reset issues on some systems | None currently |

## Current Recommendation

**Use Standalone Mode (Option 2)** for now due to pod networking issues. Pod mode will be revisited in a separate troubleshooting thread.

## Quick Start - Standalone Mode

### Prerequisites

1. Environment configured:
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

2. Images built:
   ```bash
   systemctl --user start archon-server-build.service
   systemctl --user start archon-frontend-build.service
   systemctl --user start archon-mcp-build.service
   ```

### Deploy Standalone Mode

```bash
# Switch to standalone mode and install quadlet files
./quadlet/switch-mode.sh standalone --install

# Check status
./quadlet/switch-mode.sh status
```

### Access Services

- **Frontend**: http://localhost:3737
- **API Server**: http://localhost:8181
- **MCP Server**: http://localhost:8051
- **Agents** (optional): http://localhost:8052
- **Documentation** (optional): http://localhost:3838

## Switching Between Modes

### Switch to Standalone Mode

```bash
./quadlet/switch-mode.sh standalone --install
```

### Switch to Pod Mode

```bash
./quadlet/switch-mode.sh pod --install
```

### Check Current Mode

```bash
./quadlet/switch-mode.sh status
```

## Manual Service Management

### Standalone Mode Services

- `archon-server-standalone.service` - FastAPI backend
- `archon-frontend-standalone.service` - React UI  
- `archon-mcp-standalone.service` - MCP server
- `archon-agents-standalone.service` - AI agents (optional)
- `archon-docs-standalone.service` - Documentation (optional)

### Pod Mode Services

- `archon.pod` - Main pod
- `archon-server.service` - Backend (in pod)
- `archon-frontend.service` - Frontend (in pod)
- `archon-mcp.service` - MCP server (in pod)
- `archon-agents.service` - AI agents (in pod, optional)
- `archon-docs.service` - Documentation (optional)

## Service Dependencies

### Standalone Mode

```
archon-network-network.service
├── archon-server-standalone.service
│   ├── archon-frontend-standalone.service
│   └── archon-mcp-standalone.service
└── archon-agents-standalone.service (optional)
└── archon-docs-standalone.service (optional)
```

### Pod Mode

```
archon-network-network.service
└── archon.pod
    ├── archon-server.service
    │   ├── archon-frontend.service  
    │   └── archon-mcp.service
    ├── archon-agents.service (optional)
    └── archon-docs.service (optional)
```

## File Structure

```
quadlet/
├── switch-mode.sh              # Mode switcher script
├── install.sh                  # Basic installation (pod mode)
├── DEPLOYMENT_MODES.md         # This file
│
├── # Shared Components
├── archon-network.network       # Network configuration
├── *.volume                     # Volume configurations  
├── *.build                      # Image build configurations
├── env.defaults                 # Default environment variables
│
├── # Pod Mode Files
├── archon.pod                   # Pod configuration
├── archon-server.container      # Server in pod
├── archon-frontend.container    # Frontend in pod
├── archon-mcp.container         # MCP in pod
├── archon-agents.container      # Agents in pod
├── archon-docs.container        # Docs in pod
│
└── standalone/                  # Standalone Mode Files
    ├── archon-server-standalone.container
    ├── archon-frontend-standalone.container  
    ├── archon-mcp-standalone.container
    ├── archon-agents-standalone.container
    └── archon-docs-standalone.container
```

## Environment Configuration

Both modes use the same environment files:
- `quadlet/env.defaults` - Default values
- `.env` - User-specific overrides (create from `.env.example`)

Key environment variables:
```bash
# Ports
ARCHON_SERVER_PORT=8181
ARCHON_UI_PORT=3737  
ARCHON_MCP_PORT=8051
ARCHON_AGENTS_PORT=8052
ARCHON_DOCS_PORT=3838

# Networking
ARCHON_HOST=localhost
VITE_ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0

# Docker Environment
DOCKER_ENV=true
```

## Troubleshooting

### Pod Mode Issues

If pod mode services start but aren't accessible:
1. Check pod status: `systemctl --user status archon.pod`
2. Verify port publishing: `podman ps --pod | grep archon`
3. Test internal connectivity: `podman exec archon-ui curl http://localhost:3737`
4. Switch to standalone mode as workaround

### Standalone Mode Issues  

If standalone services aren't accessible:
1. Check individual service status: `systemctl --user status archon-*-standalone.service`
2. Verify port bindings: `netstat -tlnp | grep -E ':(3737|8181|8051)'`
3. Check container logs: `podman logs <container-name>`

### General Issues

1. **Environment not loaded**: Restart services after changing `.env`
2. **Images not found**: Run build services first
3. **Port conflicts**: Ensure no other services use the same ports
4. **Network issues**: Restart `archon-network-network.service`

## Advanced Usage

### Enable Optional Services

```bash
# For agents (requires AGENTS_ENABLED=true in .env)
systemctl --user start archon-agents-standalone.service  # or archon-agents.service

# For documentation
systemctl --user start archon-docs-standalone.service    # or archon-docs.service
```

### Auto-start on Boot

```bash
# Enable services to start on login
systemctl --user enable archon-server-standalone.service
systemctl --user enable archon-frontend-standalone.service  
systemctl --user enable archon-mcp-standalone.service
```

### Development Workflow

1. Make code changes in the mounted source volumes
2. Services with `--reload` will automatically restart
3. For configuration changes, restart the specific service
4. For major changes, rebuild images and restart services

## Migration Path

When pod networking issues are resolved:
1. The pod mode files are ready and working
2. Use `./switch-mode.sh pod --install` to switch
3. All data and configuration will be preserved
4. Only the deployment architecture changes

## Support

- Pod networking issues are being tracked separately
- Standalone mode is fully supported and recommended
- Both modes use identical service configurations
- Migration between modes is seamless