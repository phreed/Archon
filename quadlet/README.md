# Archon Quadlet Installation

## Overview

This directory contains quadlet configuration files for running Archon services using rootless systemctl. 
Quadlet is a systemd generator that creates systemd services from container configuration files.

## Services

### Core Services
- **archon-server**: FastAPI backend service with crawling capabilities
- **archon-frontend**: React UI served via Vite/Node
- **archon-mcp**: Model Context Protocol server for AI integrations

### Optional Services  
- **archon-agents**: AI agents service (requires `AGENTS_ENABLED=true` and OpenAI API key)
- **archon-docs**: Docusaurus documentation site

### Supporting Resources
- **archon.pod**: Pod configuration for service networking
- **archon-network.network**: Network configuration
- **Multiple .volume files**: Persistent storage for development hot-reload
- **Multiple .build files**: Image building configurations

## Installation

### Quick Install

```bash
# Run the installation script
./quadlet/install.sh
```

The install script will:
1. ✅ Copy quadlet files to the appropriate systemd directory
2. ✅ Update EnvironmentFile paths to point to your project's `.env` and `quadlet/env.defaults`
3. ✅ Reload the systemd user daemon
4. ✅ Display available services and usage instructions

### Installation Directories

Quadlet files are installed to the first available directory:
- `$XDG_CONFIG_HOME/containers/systemd/` (config - preferred)
- `~/.config/containers/systemd/` (config fallback)

## Environment Setup

### 1. Create Environment File

The `install.sh` should have made a copy of the example `.env.example` file.
```bash
cp .env.example .env
```
Edit with the actual values
```bash
vim .env  # or your preferred editor
```

### 2. Required Configuration

Update these variables in your `.env` file:

```bash
# Required: Supabase credentials
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-actual-service-key

# Optional: OpenAI for agents
OPENAI_API_KEY=your-openai-key

# Optional: Logging
LOGFIRE_TOKEN=your-logfire-token
```

### 3. Port Configuration (Optional)

Default ports can be customized:

```bash
ARCHON_SERVER_PORT=8181    # API server
ARCHON_MCP_PORT=8051       # MCP server  
ARCHON_AGENTS_PORT=8052    # AI agents
ARCHON_UI_PORT=3737        # Frontend
ARCHON_DOCS_PORT=3838      # Documentation
```

## Usage


### Building Images

Run the code generator.
```bash
systemctl --user daemon-reload
```

Build core service container images
```bash
systemctl --user start archon-server.build
systemctl --user start archon-frontend.build
systemctl --user start archon-mcp.build
```

Build optional service container images
```bash
systemctl --user start archon-agents.build
systemctl --user start archon-docs.build
```

### Starting Services

Start core services
```bash
systemctl --user start archon-server.service
systemctl --user start archon-frontend.service
systemctl --user start archon-mcp.service
```

Start optional services
```bash
systemctl --user start archon-agents.service  # If agents enabled
systemctl --user start archon-docs.service    # For documentation
```

### Service Management

Check status
```bash
systemctl --user status archon-server.service
```
View logs
```bash
journalctl --user -u archon-server.service -f
```
Stop services
```bash
systemctl --user stop archon-server.service
```
Enable on boot
```bash
systemctl --user enable archon-server.service
```
List all archon services
```bash
systemctl --user list-units 'archon-*'
```

## Service Dependencies

- `archon-frontend` depends on `archon-server` (via Unit After/Requires)
- `archon-mcp` depends on `archon-server` (via Unit After/Requires)
- `archon-agents` is independent (when enabled)
- `archon-docs` is independent

## Service URLs

Default URLs when services are running:

| Service | URL | Purpose |
|---------|-----|---------|
| Frontend | http://localhost:3737 | Main user interface |
| API Server | http://localhost:8181 | Backend API endpoints |
| MCP Server | http://localhost:8051 | Model Context Protocol |
| Agents | http://localhost:8052 | AI agents service |
| Documentation | http://localhost:3838 | Project documentation |

## Troubleshooting

### Common Issues

**Services won't start:**
```bash
# Check logs for specific service
journalctl --user -u archon-server.service -n 50

# Check if environment file exists
ls -la ../.env

# Verify quadlet files were installed
ls -la ~/.config/containers/systemd/
```

**Port conflicts:**
```bash
# Check if ports are in use
ss -tulpn | grep :8181
```

**Build failures:**
```bash
# Check build logs
journalctl --user -u archon-server.build -n 50

# Manually trigger build
systemctl --user start archon-server.build
```

### Debug Commands

Reload systemd configuration
```bash
systemctl --user daemon-reload
```
Reset failed services
```bash
systemctl --user reset-failed
```
Show service dependencies
```bash
systemctl --user list-dependencies archon-frontend.service
```
Check environment variables
```bash
systemctl --user show archon-server.service -p Environment
```
Keep the service active after reboot (and on logout)
```bash
loginctl enable-linger <user_id>
```

## File Structure

```
quadlet/
├── install.sh                    # Installation script
├── env.defaults                  # Environment variables template
├── README.md                     # This file
├── archon.pod                    # Pod configuration
├── archon-network.network        # Network configuration
├── archon-server.build           # Server build config
├── archon-server.container       # Server container config
├── archon-server-*.volume        # Server volumes
├── archon-frontend.build         # Frontend build config
├── archon-frontend.container     # Frontend container config
├── archon-frontend-*.volume      # Frontend volumes
├── archon-mcp.build              # MCP build config
├── archon-mcp.container          # MCP container config
├── archon-agents.build           # Agents build config
├── archon-agents.container       # Agents container config
├── archon-docs.build             # Docs build config
└── archon-docs.container         # Docs container config
```

## Benefits of Quadlet

1. **Native systemd Integration**: Services managed like any other systemd service
2. **Automatic Dependency Management**: Proper startup ordering and dependency handling
3. **Logging Integration**: Logs available via `journalctl`
4. **Resource Management**: CPU/memory limits via systemd
5. **Auto-restart**: Built-in failure recovery
6. **User Sessions**: Rootless containers with proper user session management

## Notes

- All container files use `EnvironmentFile` for centralized configuration
- Build files create images locally (no registry required)
- Volume mounts enable hot-reload for development
- Health checks ensure service reliability
- Services use pod networking for internal communication
