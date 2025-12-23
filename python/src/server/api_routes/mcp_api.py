"""
MCP API endpoints for Archon

Provides status and configuration endpoints for the MCP service.
The MCP service runs independently and status is checked via HTTP.
"""

import os
from typing import Any

import httpx
from fastapi import APIRouter, HTTPException

# Import unified logging
from ..config.logfire_config import api_logger, safe_set_attribute, safe_span

router = APIRouter(prefix="/api/mcp", tags=["mcp"])


def get_mcp_service_status() -> dict[str, Any]:
    """Get MCP service status via port connectivity check."""
    try:
        # Get MCP port from environment or use default
        mcp_port = int(os.getenv("ARCHON_MCP_PORT", "8051"))
        # Use container name for inter-container communication, fallback to localhost
        mcp_host = os.getenv("ARCHON_MCP_HOST", "archon-mcp" if os.getenv("DOCKER_ENV") else "localhost")

        # Try to connect to MCP service port (simple connectivity test)
        import socket

        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(3.0)  # 3 second timeout
        result = sock.connect_ex((mcp_host, mcp_port))
        sock.close()

        if result == 0:
            # Port is open, service is likely running
            return {
                "status": "running",
                "uptime": None,  # Cannot determine uptime without container access
                "logs": [],
                "container_status": "running",
                "health_check": "port_open",
                "mcp_url": f"http://{mcp_host}:{mcp_port}/mcp",
            }
        else:
            return {
                "status": "not_found",
                "uptime": None,
                "logs": [],
                "container_status": "not_found",
                "message": f"MCP service not reachable at {mcp_host}:{mcp_port}. Check if archon-mcp service is running.",
                "mcp_url": f"http://{mcp_host}:{mcp_port}/mcp",
            }

    except Exception as e:
        api_logger.error("Failed to check MCP service status", exc_info=True)
        return {"status": "error", "uptime": None, "logs": [], "container_status": "error", "error": str(e)}


@router.get("/status")
async def get_status():
    """Get MCP server status."""
    with safe_span("api_mcp_status") as span:
        safe_set_attribute(span, "endpoint", "/api/mcp/status")
        safe_set_attribute(span, "method", "GET")

        try:
            status = get_mcp_service_status()
            api_logger.debug(f"MCP server status checked - status={status.get('status')}")
            safe_set_attribute(span, "status", status.get("status"))
            safe_set_attribute(span, "uptime", status.get("uptime"))
            return status
        except Exception as e:
            api_logger.error(f"MCP server status API failed - error={str(e)}")
            safe_set_attribute(span, "error", str(e))
            raise HTTPException(status_code=500, detail=str(e))


@router.get("/config")
async def get_mcp_config():
    """Get MCP server configuration."""
    with safe_span("api_get_mcp_config") as span:
        safe_set_attribute(span, "endpoint", "/api/mcp/config")
        safe_set_attribute(span, "method", "GET")

        try:
            api_logger.info("Getting MCP server configuration")

            # Get actual MCP port from environment or use default
            mcp_port = int(os.getenv("ARCHON_MCP_PORT", "8051"))

            # Configuration for streamable-http mode with actual port
            config = {
                "host": os.getenv("ARCHON_HOST", "localhost"),
                "port": mcp_port,
                "transport": "streamable-http",
            }

            # Get only model choice from database (simplified)
            try:
                from ..services.credential_service import credential_service

                model_choice = await credential_service.get_credential(
                    "MODEL_CHOICE", "gpt-4o-mini"
                )
                config["model_choice"] = model_choice
            except Exception:
                # Fallback to default model
                config["model_choice"] = "gpt-4o-mini"

            api_logger.info("MCP configuration (streamable-http mode)")
            safe_set_attribute(span, "host", config["host"])
            safe_set_attribute(span, "port", config["port"])
            safe_set_attribute(span, "transport", "streamable-http")
            safe_set_attribute(span, "model_choice", config.get("model_choice", "gpt-4o-mini"))

            return config
        except Exception as e:
            api_logger.error("Failed to get MCP configuration", exc_info=True)
            safe_set_attribute(span, "error", str(e))
            raise HTTPException(status_code=500, detail={"error": str(e)})


@router.get("/clients")
async def get_mcp_clients():
    """Get connected MCP clients with type detection."""
    with safe_span("api_mcp_clients") as span:
        safe_set_attribute(span, "endpoint", "/api/mcp/clients")
        safe_set_attribute(span, "method", "GET")

        try:
            # TODO: Implement real client detection in the future
            # For now, return empty array as expected by frontend
            api_logger.debug("Getting MCP clients - returning empty array")

            return {
                "clients": [],
                "total": 0
            }
        except Exception as e:
            api_logger.error(f"Failed to get MCP clients - error={str(e)}")
            safe_set_attribute(span, "error", str(e))
            return {
                "clients": [],
                "total": 0,
                "error": str(e)
            }


@router.get("/sessions")
async def get_mcp_sessions():
    """Get MCP session information."""
    with safe_span("api_mcp_sessions") as span:
        safe_set_attribute(span, "endpoint", "/api/mcp/sessions")
        safe_set_attribute(span, "method", "GET")

        try:
            # Basic session info for now
            status = get_mcp_service_status()

            session_info = {
                "active_sessions": 0,  # TODO: Implement real session tracking
                "session_timeout": 3600,  # 1 hour default
            }

            # Add uptime if server is running
            if status.get("status") == "running" and status.get("uptime"):
                session_info["server_uptime_seconds"] = status["uptime"]

            api_logger.debug(f"MCP session info - sessions={session_info.get('active_sessions')}")
            safe_set_attribute(span, "active_sessions", session_info.get("active_sessions"))

            return session_info
        except Exception as e:
            api_logger.error(f"Failed to get MCP sessions - error={str(e)}")
            safe_set_attribute(span, "error", str(e))
            raise HTTPException(status_code=500, detail=str(e))


@router.get("/health")
async def mcp_health():
    """Health check for MCP API - used by bug report service and tests."""
    with safe_span("api_mcp_health") as span:
        safe_set_attribute(span, "endpoint", "/api/mcp/health")
        safe_set_attribute(span, "method", "GET")

        # Simple health check - no logging to reduce noise
        result = {"status": "healthy", "service": "mcp"}
        safe_set_attribute(span, "status", "healthy")

        return result
