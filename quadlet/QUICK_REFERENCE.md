# Archon Pod Networking - Quick Reference Card

## 🚨 Got Connection Reset Errors?

```bash
# IMMEDIATE FIX:
./switch-mode.sh pod --install
```

## 🎯 Quick Commands

### Switch Deployment Modes
```bash
./switch-mode.sh pod --install         # ⭐ Best: Host networking pod
./switch-mode.sh standalone --install  # ⭐ Safe: Individual containers
```

### Test & Diagnose
```bash
./test-connectivity.sh --quick         # Quick test
./diagnose-networking.sh               # Full analysis
./switch-mode.sh status                # Current mode
```

### Manual Testing
```bash
curl http://localhost:3737             # Frontend
curl http://localhost:8181/health      # API Server  
curl http://localhost:8051/health      # MCP Server
```

## 📊 Mode Comparison

| Mode | Reliability | Performance | Use Case |
|------|-------------|-------------|----------|
| `pod` | ⭐⭐⭐ | ⭐⭐⭐ | Production (host networking) |
| `standalone` | ⭐⭐⭐ | ⭐⭐ | Development & debugging |

## 🩺 Troubleshooting Workflow

1. **Check Status**: `./switch-mode.sh status`
2. **Test Connectivity**: `./test-connectivity.sh --quick`
3. **If Failed**: `./switch-mode.sh pod --install`
4. **Verify Fix**: `curl http://localhost:3737`
5. **Still Issues?**: `./diagnose-networking.sh`

## 🆘 Common Issues & Fixes

### "Connection reset by peer"
```bash
./switch-mode.sh pod --install
```

### "Port already in use"  
```bash
./switch-mode.sh status                # Check what's running
systemctl --user stop archon-*        # Stop all services
./switch-mode.sh pod --install         # Restart in pod mode
```

### Services won't start
```bash
journalctl --user -u archon-server.service -n 20   # Check logs
./diagnose-networking.sh                           # Full analysis
```

### Can't access frontend
```bash
# Test in order:
curl http://localhost:8181/health      # API first
curl http://localhost:3737             # Then frontend
./switch-mode.sh pod --install         # Fix if needed
```

## 📋 Service URLs

- **Frontend**: http://localhost:3737
- **API Server**: http://localhost:8181  
- **API Health**: http://localhost:8181/health
- **MCP Server**: http://localhost:8051
- **MCP Health**: http://localhost:8051/health

## 🔄 Mode Switching Examples

```bash
# Production deployment (recommended)
./switch-mode.sh pod --install

# Development (easy debugging)  
./switch-mode.sh standalone --install

# Check what's currently running
./switch-mode.sh status
```

## 🚀 Quick Start from Scratch

```bash
# 1. Install and switch to pod mode (host networking)
./switch-mode.sh pod --install

# 2. Test everything works
./test-connectivity.sh --quick

# 3. Access the application
open http://localhost:3737
```

## 💡 Why Pod Mode Works

- **Host networking** bypasses pasta networking completely
- **Direct port binding** eliminates connection resets
- **Maximum performance** with no network translation
- **Production ready** and reliable

## 📚 More Information

- **[NETWORKING_FIXES.md](NETWORKING_FIXES.md)** - Detailed solutions
- **[POD_NETWORKING_ISSUE.md](POD_NETWORKING_ISSUE.md)** - Technical analysis  
- **[README.md](README.md)** - Complete documentation

---
**🎯 TL;DR**: Having pod networking issues? Run `./switch-mode.sh pod --install`
