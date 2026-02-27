"""
Direct MCP Client - Custom Headers Sample

This sample demonstrates how to pass custom headers when making direct
HTTP calls to an MCP server. Shows a reusable MCPClient class with
proper session management for the MCP Streamable HTTP transport.

Usage:
    uv run direct_mcp_client.py
"""

import asyncio
import json
import os
import uuid
from typing import Any

import httpx
from azure.identity import DefaultAzureCredential
from dotenv import load_dotenv

load_dotenv()


class MCPClient:
    """
    A simple MCP client that demonstrates custom header handling.
    
    Supports the MCP Streamable HTTP transport with proper session management.
    """
    
    def __init__(
        self,
        base_url: str,
        oauth_token: str | None = None,
        custom_headers: dict[str, str] | None = None
    ):
        """
        Initialize the MCP client.
        
        Args:
            base_url: The base URL of the MCP server
            oauth_token: OAuth bearer token for authentication
            custom_headers: Additional headers to pass to the server
        """
        self.base_url = base_url.rstrip("/")
        self.oauth_token = oauth_token
        self.custom_headers = custom_headers or {}
        self._request_id = 0
        self._session_id: str | None = None
        self._initialized = False
    
    def _get_headers(self, correlation_id: str | None = None) -> dict[str, str]:
        """Build the complete headers dictionary for a request."""
        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",  # MCP requires both
        }
        
        if self._session_id:
            headers["mcp-session-id"] = self._session_id
        
        if self.oauth_token:
            headers["Authorization"] = f"Bearer {self.oauth_token}"
        
        headers["x-correlation-id"] = correlation_id or str(uuid.uuid4())
        headers.update(self.custom_headers)
        
        return headers
    
    def _next_request_id(self) -> int:
        self._request_id += 1
        return self._request_id
    
    async def _send_request(
        self,
        method: str,
        params: dict[str, Any] | None = None,
        correlation_id: str | None = None
    ) -> dict[str, Any]:
        """Send a JSON-RPC request to the MCP server."""
        headers = self._get_headers(correlation_id)
        
        payload = {
            "jsonrpc": "2.0",
            "method": method,
            "id": self._next_request_id()
        }
        if params:
            payload["params"] = params
        
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(self.base_url, headers=headers, json=payload)
            response.raise_for_status()
            
            # Capture session ID from response
            if "mcp-session-id" in response.headers:
                self._session_id = response.headers["mcp-session-id"]
            
            # Handle SSE responses
            content_type = response.headers.get("content-type", "")
            if "text/event-stream" in content_type:
                for line in response.text.strip().split("\n"):
                    if line.startswith("data:"):
                        return json.loads(line[5:].strip())
                return {}
            return response.json()
    
    async def initialize(self) -> dict[str, Any]:
        """Initialize the MCP session. Must be called first."""
        params = {
            "protocolVersion": "2025-03-26",
            "capabilities": {},
            "clientInfo": {"name": "custom-headers-client", "version": "1.0.0"}
        }
        result = await self._send_request("initialize", params=params)
        self._initialized = True
        return result.get("result", {})
    
    async def _ensure_initialized(self):
        if not self._initialized:
            await self.initialize()
    
    async def list_tools(self) -> list[dict]:
        """List available tools from the MCP server."""
        await self._ensure_initialized()
        result = await self._send_request("tools/list")
        return result.get("result", {}).get("tools", [])
    
    async def call_tool(self, tool_name: str, arguments: dict[str, Any] | None = None) -> Any:
        """Call a tool on the MCP server."""
        await self._ensure_initialized()
        params = {"name": tool_name, "arguments": arguments or {}}
        result = await self._send_request("tools/call", params=params)
        return result.get("result", {}).get("content", [])


def get_oauth_token() -> str | None:
    """Get an OAuth token using Azure credentials."""
    try:
        credential = DefaultAzureCredential()
        scope = os.environ.get("MCP_OAUTH_SCOPE", "api://mcp-server/.default")
        token = credential.get_token(scope)
        return token.token
    except Exception as e:
        print(f"⚠ Could not obtain OAuth token: {e}")
        return None


async def main():
    """Demo: List tools and call get_weather with custom headers."""
    print("=" * 60)
    print("MCP Custom Headers - Direct Client Demo")
    print("=" * 60)
    
    mcp_url = os.environ.get("MCP_SERVER_URL")
    if not mcp_url:
        print("⚠ MCP_SERVER_URL not set. Copy .env.sample to .env and configure.")
        return
    
    # Get OAuth token
    oauth_token = get_oauth_token()
    if not oauth_token:
        return
    
    print(f"\n✓ OAuth token acquired")
    
    # Create client with custom headers
    client = MCPClient(
        base_url=mcp_url,
        oauth_token=oauth_token,
        custom_headers={
            "x-customer-id": "demo-customer",
            "x-tenant-id": "demo-tenant"
        }
    )
    
    print(f"\n📤 Custom headers:")
    print(f"   x-customer-id: demo-customer")
    print(f"   x-tenant-id: demo-tenant")
    
    # Initialize and show server info
    print(f"\n" + "-" * 60)
    print("Step 1: Initialize Session")
    print("-" * 60)
    
    server_info = await client.initialize()
    print(f"✓ Connected to: {server_info.get('serverInfo', {}).get('name')}")
    print(f"✓ Session ID: {client._session_id[:20]}...")
    
    # List tools
    print(f"\n" + "-" * 60)
    print("Step 2: List Tools")
    print("-" * 60)
    
    tools = await client.list_tools()
    print(f"\n📥 Response: Found {len(tools)} tools:")
    for tool in tools:
        print(f"   • {tool.get('name')}: {tool.get('description', '')[:50]}...")
    
    # Call get_weather
    print(f"\n" + "-" * 60)
    print("Step 3: Call get_weather Tool")
    print("-" * 60)
    
    print(f'\n📤 Request: call_tool("get_weather", {{"location": "Mount Rainier"}})')
    
    result = await client.call_tool("get_weather", {"location": "Mount Rainier"})
    
    print(f"\n📥 Response:")
    for item in result:
        if item.get("type") == "text":
            weather = json.loads(item.get("text", "{}"))
            print(json.dumps(weather, indent=3))
    
    print(f"\n" + "=" * 60)
    print("✓ Demo complete")
    print("=" * 60)


if __name__ == "__main__":
    asyncio.run(main())
