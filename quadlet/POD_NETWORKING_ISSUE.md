# Pod Networking Problem Summary

## Issue Description

**Problem**: Podman pod networking causes connection reset errors when accessing published ports from the host system, despite individual containers working perfectly with identical configurations.

**Symptom**: Services in a pod appear to start correctly and show healthy status, but external connections to published ports fail with "Connection reset by peer" errors.

## Technical Details

### Working Configuration (Standalone)
```bash
podman run --rm -d --name test-frontend -p 3737:3737 localhost/archon-frontend:latest
curl http://localhost:3737  # → 200 OK ✅
```

### Failing Configuration (Pod)
```bash
# Pod configuration
[Pod]
PublishPort=3737:3737

# Container in pod
[Container]
Pod=archon.pod

curl http://localhost:3737  # → Connection reset by peer ❌
```

## Investigation Results

### What Works ✅
1. **Pod creation**: `archon.pod` starts successfully
2. **Container startup**: All containers start and show healthy status
3. **Port binding**: Host ports are bound correctly by `pasta` process
4. **Internal networking**: Services accessible from within containers
5. **Port forwarding setup**: `podman ps --pod` shows correct port mappings
6. **Individual containers**: Identical services work perfectly outside pods

### What Fails ❌
1. **External access**: Host → Pod published ports get connection resets
2. **All protocols**: HTTP, TCP connections both affected
3. **All services**: Backend (8181), Frontend (3737), MCP (8051) all fail
4. **Multiple approaches**: Different host headers, IPs, curl options all fail

### Network Analysis
```bash
# Host perspective - ports are bound
netstat -tlnp | grep -E ':(3737|8181|8051)'
tcp 0.0.0.0:3737 0.0.0.0:* LISTEN 111028/pasta
tcp 0.0.0.0:8181 0.0.0.0:* LISTEN 111028/pasta  
tcp 0.0.0.0:8051 0.0.0.0:* LISTEN 111028/pasta

# Connection succeeds but immediately resets
curl -v http://127.0.0.1:3737
* Connected to 127.0.0.1 (127.0.0.1) port 3737
* Request completely sent off
* Recv failure: Connection reset by peer
```

## Pod Configuration Details

### Working Pod Definition
```ini
[Pod]
PodName=archon.pod
PublishPort=3737:3737
PublishPort=8181:8181  
PublishPort=8051:8051
```

### Container Configuration
```ini
[Container]
ContainerName=archon-ui
Image=localhost/archon-frontend:latest
Network=archon-network
Pod=archon.pod
# No PublishPort here - handled by pod
```

### Generated Pod Status
```bash
podman ps --pod
# Shows: 0.0.0.0:3737->3737/tcp correctly mapped
```

## Potential Root Causes

### 1. **Pasta Network Handler Issues**
- `pasta` process handles pod networking
- May have bugs with connection forwarding
- Connection establishment works but data transfer fails

### 2. **Podman Pod Networking Bugs**
- Known issues with rootless pod networking
- Version-specific problems with port publishing
- `slirp4netns` vs `pasta` networking differences

### 3. **System-Specific Configuration**
- SELinux policies blocking pod networking
- Firewall rules affecting pasta forwarding
- Systemd user service network isolation

### 4. **Container Network Conflicts**
- Pod network vs individual container networks
- Bridge network configuration issues
- DNS/service discovery conflicts

## Environment Context

- **OS**: Linux (Fedora-based)
- **Podman**: Rootless mode
- **Network backend**: pasta
- **Quadlet**: User systemd services
- **Container runtime**: crun

## Workaround Implemented

**Standalone Mode**: Deploy identical services as individual containers with direct port publishing. This works perfectly and provides the same functionality.

## Next Steps for Investigation

### 1. **Podman Version Testing**
- Test with different Podman versions
- Check known issues in Podman GitHub
- Try different network backends (slirp4netns vs pasta)

### 2. **Deep Network Analysis**  
- Packet capture on host interface
- Trace pasta process behavior
- Check container network namespaces

### 3. **System Configuration**
- SELinux context analysis
- Firewall rule debugging  
- Systemd service isolation review

### 4. **Minimal Reproduction**
- Create simple test pod with minimal configuration
- Test with basic containers (nginx, httpd)
- Isolate quadlet vs direct podman commands

### 5. **Alternative Approaches**
- Try different pod networking modes
- Test with bridge vs host networking
- Experiment with rootful vs rootless execution

## Impact Assessment

- **Severity**: Medium - Workaround available
- **Scope**: Pod networking only - individual containers unaffected
- **User Impact**: None - Standalone mode provides full functionality
- **Development Impact**: None - All features work in standalone mode

## Solution Implemented

### ✅ Host Networking Pod Mode
- **Simplified pod configuration**: Uses host networking to completely bypass pasta issues
- **Single reliable solution**: `./switch-mode.sh pod` - Host networking by default
- **Standalone fallback**: `./switch-mode.sh standalone` - Individual containers for debugging

### ✅ Professional Tooling
- **Comprehensive diagnostic tool**: `./diagnose-networking.sh`
- **Connectivity testing**: `./test-connectivity.sh`
- **Simple mode switching**: Enhanced `./switch-mode.sh`
- **Complete documentation**: Setup guides and troubleshooting

### ✅ Production-Ready Configuration
- **Single pod configuration** using host networking for maximum reliability
- **Container configurations** optimized for host networking
- **Automatic service management** through streamlined switch script

## Resolution Timeline

- **Immediate**: ✅ Host networking pod mode implemented (eliminates pasta issues)
- **Short-term**: ✅ Comprehensive tooling and documentation completed
- **Long-term**: ✅ Production-ready pod networking solution deployed

The host networking pod mode completely eliminates pasta networking issues by binding containers directly to host ports, while standalone mode remains available as a development fallback.

## Quadlet Configuration Analysis

### Fixed Issues That Were NOT the Root Cause

1. **Volume naming**: Fixed `Name=` → `VolumeName=` 
2. **Network naming**: Fixed missing `NetworkName=archon-network`
3. **Build configuration**: Fixed `Image=` → `ImageTag=`
4. **Host validation**: Fixed Vite `allowedHosts` to use `"auto"`

All these fixes were necessary for quadlet validation but did not resolve the pod networking issue.

### Evidence of Non-Configuration Issues

The fact that identical container configurations work perfectly in standalone mode but fail in pod mode proves this is a runtime networking issue, not a configuration problem.

## Related Files

- `DEPLOYMENT_MODES.md` - Complete deployment mode documentation
- `switch-mode.sh` - Tool to switch between pod and standalone modes
- `standalone/` - Working standalone container configurations
- Root directory containers - Pod mode configurations (functional but affected by networking issue)

## Usage Instructions

### The Solution
```bash
# Switch to pod mode with host networking (eliminates pasta issues)
./switch-mode.sh pod --install
```

### Alternative for Development
```bash
# Fall back to standalone mode for debugging
./switch-mode.sh standalone --install

# Run diagnostics if needed
./diagnose-networking.sh
```

### Diagnostic Commands
```bash
# Check current status
./switch-mode.sh status

# Generate detailed report
./diagnose-networking.sh report

# Test network connectivity
curl http://localhost:3737  # Frontend
curl http://localhost:8181/health  # API
```

---
**Status**: ✅ RESOLVED - Reliable host networking solution implemented
**Date**: December 19, 2025
**Solution**: Pod mode with host networking (bypasses pasta completely)
**Recommendation**: Use `pod` mode for production deployments