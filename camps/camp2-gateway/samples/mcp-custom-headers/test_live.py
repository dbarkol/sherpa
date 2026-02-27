#!/usr/bin/env python3
"""
MCP Custom Headers - Live Test

Demonstrates passing custom headers to an MCP server:
1. List available tools
2. Call get_weather tool

Usage:
    uv run test_live.py
"""
import os
import subprocess
import json
import httpx
from dotenv import load_dotenv

load_dotenv()

# =============================================================================
# Configuration
# =============================================================================

MCP_URL = os.environ.get("MCP_SERVER_URL")
OAUTH_SCOPE = os.environ.get("MCP_OAUTH_SCOPE")
TENANT_ID = os.environ.get("AZURE_TENANT_ID", "")

if not MCP_URL:
    print("⚠ MCP_SERVER_URL not configured. Copy .env.sample to .env and configure.")
    exit(1)

# =============================================================================
# Get OAuth Token
# =============================================================================

print("=" * 60)
print("MCP Custom Headers - Sherpa Server Demo")
print("=" * 60)

# Extract resource from scope (api://xxx/.default → api://xxx)
resource = OAUTH_SCOPE.replace("/.default", "") if OAUTH_SCOPE else None
cmd = ["az", "account", "get-access-token", "--query", "accessToken", "-o", "tsv"]
if resource:
    cmd.extend(["--resource", resource])
if TENANT_ID:
    cmd.extend(["--tenant", TENANT_ID])

result = subprocess.run(cmd, capture_output=True, text=True)
token = result.stdout.strip()
if not token:
    print(f"⚠ Failed to get token: {result.stderr}")
    exit(1)
print(f"\n✓ OAuth token acquired")

# =============================================================================
# Custom Headers
# =============================================================================

headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json",
    "Accept": "application/json, text/event-stream",
    # Custom context headers - these flow through to the MCP server
    "x-customer-id": "demo-customer",
    "x-tenant-id": "demo-tenant",
    "x-correlation-id": "test-12345"
}

print(f"\n📤 Custom headers being sent:")
print(f"   x-customer-id: demo-customer")
print(f"   x-tenant-id: demo-tenant")
print(f"   x-correlation-id: test-12345")

# =============================================================================
# Helper: Parse SSE Response
# =============================================================================

def parse_response(response):
    """Parse SSE or JSON response."""
    content_type = response.headers.get("content-type", "")
    if "text/event-stream" in content_type:
        for line in response.text.strip().split("\n"):
            if line.startswith("data:"):
                return json.loads(line[5:].strip())
    return response.json()

# =============================================================================
# Step 1: Initialize MCP Session
# =============================================================================

print(f"\n" + "-" * 60)
print("Step 1: Initialize MCP Session")
print("-" * 60)

init_payload = {
    "jsonrpc": "2.0",
    "method": "initialize",
    "id": 1,
    "params": {
        "protocolVersion": "2025-03-26",
        "capabilities": {},
        "clientInfo": {"name": "custom-headers-demo", "version": "1.0.0"}
    }
}

response = httpx.post(MCP_URL, headers=headers, json=init_payload, timeout=30)
session_id = response.headers.get("mcp-session-id")
data = parse_response(response)

print(f"✓ Connected to: {data.get('result', {}).get('serverInfo', {}).get('name')}")
print(f"✓ Session ID: {session_id[:20]}...")

# Add session ID for subsequent requests
headers["mcp-session-id"] = session_id

# =============================================================================
# Step 2: List Tools
# =============================================================================

print(f"\n" + "-" * 60)
print("Step 2: List Tools")
print("-" * 60)

print(f"\n📤 Request:")
print(f'   {{"jsonrpc": "2.0", "method": "tools/list", "id": 2}}')

list_payload = {"jsonrpc": "2.0", "method": "tools/list", "id": 2}
response = httpx.post(MCP_URL, headers=headers, json=list_payload, timeout=30)
data = parse_response(response)

print(f"\n📥 Response:")
tools = data.get("result", {}).get("tools", [])
print(f"   Found {len(tools)} tools:")
for tool in tools:
    print(f"   • {tool.get('name')}: {tool.get('description', '')[:50]}...")

# =============================================================================
# Step 3: Call get_weather Tool
# =============================================================================

print(f"\n" + "-" * 60)
print("Step 3: Call get_weather Tool")
print("-" * 60)

call_payload = {
    "jsonrpc": "2.0",
    "method": "tools/call",
    "id": 3,
    "params": {
        "name": "get_weather",
        "arguments": {"location": "Mount Rainier"}
    }
}

print(f"\n📤 Request:")
print(json.dumps(call_payload, indent=3))

response = httpx.post(MCP_URL, headers=headers, json=call_payload, timeout=30)
data = parse_response(response)

print(f"\n📥 Response:")
content = data.get("result", {}).get("content", [])
for item in content:
    if item.get("type") == "text":
        weather = json.loads(item.get("text", "{}"))
        print(json.dumps(weather, indent=3))

print(f"\n" + "=" * 60)
print("✓ Demo complete - custom headers passed through successfully")
print("=" * 60)
