"""
Agent Framework - MCP Custom Headers Sample

Demonstrates how to pass custom headers to an MCP server using the
Microsoft Agent Framework with AzureOpenAIResponsesClient.

Shows:
1. List available tools via MCP
2. Call get_weather tool

Based on latest patterns from:
https://github.com/microsoft/agent-framework/tree/main/python/samples

Usage:
    uv run agent_framework_headers.py
"""

import asyncio
import os

from agent_framework import Agent
from agent_framework.azure import AzureOpenAIResponsesClient
from azure.identity import AzureCliCredential
from dotenv import load_dotenv

load_dotenv()


def get_oauth_token(scope: str) -> str:
    """Get OAuth token for the MCP server."""
    credential = AzureCliCredential()
    token = credential.get_token(scope)
    return token.token


async def main():
    print("=" * 60)
    print("MCP Custom Headers - Agent Framework Demo")
    print("=" * 60)

    # Configuration
    mcp_url = os.environ.get("MCP_SERVER_URL")
    mcp_scope = os.environ.get("MCP_OAUTH_SCOPE", "api://mcp-server/.default")
    project_endpoint = os.environ.get("AZURE_AI_PROJECT_ENDPOINT")
    deployment_name = os.environ.get(
        "AZURE_OPENAI_RESPONSES_DEPLOYMENT_NAME",
        os.environ.get("AZURE_AI_MODEL", "gpt-4.1-mini"),
    )

    if not mcp_url:
        print("⚠ MCP_SERVER_URL not set. Copy .env.sample to .env and configure.")
        return

    if not project_endpoint:
        print("⚠ AZURE_AI_PROJECT_ENDPOINT not set.")
        print("   This sample requires an Azure AI Foundry project.")
        print("\n   Showing configuration pattern instead:\n")
        demonstrate_config_pattern(mcp_url, mcp_scope)
        return

    # Get OAuth token for MCP server
    print(f"\n✓ Getting OAuth token...")
    oauth_token = get_oauth_token(mcp_scope)
    print(f"✓ Token acquired")

    # Custom headers to pass to MCP server
    custom_headers = {
        "Authorization": f"Bearer {oauth_token}",
        "x-customer-id": "demo-customer",
        "x-tenant-id": "demo-tenant",
        "x-correlation-id": "agent-framework-demo",
    }

    print(f"\n📤 Custom headers:")
    for k, v in custom_headers.items():
        if k == "Authorization":
            print(f"   {k}: Bearer <token>")
        else:
            print(f"   {k}: {v}")

    print(f"\n" + "-" * 60)
    print("MCP Tool Configuration")
    print("-" * 60)
    print(f"   name: sherpa")
    print(f"   url: {mcp_url}")
    print(f"   headers: {list(custom_headers.keys())}")
    print(f"   approval_mode: never_require")

    # Create Azure OpenAI client for Foundry
    print(f"\n" + "-" * 60)
    print("Using with Azure AI Foundry")
    print("-" * 60)
    print(f"   project_endpoint: {project_endpoint}")
    print(f"   deployment_name: {deployment_name}")

    credential = AzureCliCredential()
    client = AzureOpenAIResponsesClient(
        project_endpoint=project_endpoint,
        deployment_name=deployment_name,
        credential=credential,
    )

    # Create MCP tool with custom headers using client.get_mcp_tool()
    mcp_tool = client.get_mcp_tool(
        name="sherpa",
        url=mcp_url,
        headers=custom_headers,
        approval_mode="never_require",
    )

    # Create agent with MCP tools
    async with Agent(
        client=client,
        name="SherpaAgent",
        instructions=(
            "You are a helpful assistant that can get weather information "
            "and trail conditions using tools from the sherpa MCP server."
        ),
        tools=mcp_tool,
    ) as agent:
        # Query 1: List available tools
        print(f"\n" + "-" * 60)
        print("Listing Available Tools")
        print("-" * 60)

        query1 = "What MCP tools are available to you?"
        print(f'\n📤 Request: "{query1}"')
        result1 = await agent.run(query1)
        print(f"\n📥 Response:\n{result1.text}")

        # Query 2: Call get_weather
        print(f"\n" + "-" * 60)
        print("Calling get_weather Tool")
        print("-" * 60)

        query2 = "What is the weather on Mount Rainier?"
        print(f'\n📤 Request: "{query2}"')
        result2 = await agent.run(query2)
        print(f"\n📥 Response:\n{result2.text}")

    print(f"\n" + "=" * 60)
    print("✓ Demo complete")
    print("=" * 60)


def demonstrate_config_pattern(mcp_url: str, mcp_scope: str):
    """Show the configuration pattern without a live Foundry connection."""

    print("Configuration Pattern:")
    print("-" * 40)
    print(
        """
import asyncio
import os
from agent_framework import Agent
from agent_framework.azure import AzureOpenAIResponsesClient
from azure.identity import AzureCliCredential

# Get OAuth token for MCP server
credential = AzureCliCredential()
token = credential.get_token("{scope}")

# Custom headers to pass to MCP server
custom_headers = {{
    "Authorization": f"Bearer {{token.token}}",
    "x-customer-id": "demo-customer",
    "x-tenant-id": "demo-tenant",
}}

# Create Azure AI Foundry client
client = AzureOpenAIResponsesClient(
    project_endpoint=os.environ["AZURE_AI_PROJECT_ENDPOINT"],
    deployment_name=os.environ["AZURE_OPENAI_RESPONSES_DEPLOYMENT_NAME"],
    credential=credential,
)

# Create MCP tool with custom headers
mcp_tool = client.get_mcp_tool(
    name="sherpa",
    url="{url}",
    headers=custom_headers,
    approval_mode="never_require",
)

# Use with Agent
async def run():
    async with Agent(
        client=client,
        name="SherpaAgent",
        instructions="You are a helpful assistant.",
        tools=mcp_tool,
    ) as agent:
        result = await agent.run("What is the weather on Mount Rainier?")
        print(result.text)

asyncio.run(run())
""".format(url=mcp_url, scope=mcp_scope)
    )


if __name__ == "__main__":
    asyncio.run(main())
