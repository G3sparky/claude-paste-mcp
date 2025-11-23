#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";
import { spawn } from "child_process";
import path from "path";
import { fileURLToPath } from "url";
// Setup paths
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const POWERSHELL_SCRIPT = path.join(__dirname, "..", "powershell", "PastePopup.ps1");
// Initialize MCP Server
const server = new Server(
  {
    name: "claude-paste-mcp",
    version: "0.1.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);
const TOOL_NAME = "collect_pasted_items";
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: TOOL_NAME,
        description: "Opens a Windows popup to let the user paste images (and eventually text/tables) from their clipboard. Use this when the user indicates they want to attach content (e.g. via @pic).",
        inputSchema: {
          type: "object",
          properties: {
            prompt_context: {
              type: "string",
              description: "Optional context about what the user is expected to paste."
            }
          },
        },
      },
    ],
  };
});
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  if (request.params.name !== TOOL_NAME) {
    throw new Error(`Unknown tool: ${request.params.name}`);
  }
  try {
    const items = await runPowerShellPopup();
    
    // If empty array, treat as cancel
    if (!items || items.length === 0) {
      return {
        content: [
          {
            type: "text",
            text: "User cancelled the paste operation or no items were confirmed.",
          },
        ],
      };
    }
    // Build friendly summary
    const count = items.length;
    const itemNames = items.map(i => i.name).join(", ");
    const summaryText = count === 1 
      ? `[1 image attached: ${items[0].name} (path: ${items[0].path})]`
      : `[${count} images attached: ${itemNames}]`;
    // Build machine-readable JSON block
    const jsonBlock = `ITEMS_JSON: ${JSON.stringify(items)}`;
    return {
      content: [
        {
          type: "text",
          text: summaryText,
        },
        {
          type: "text",
          text: jsonBlock,
        }
      ],
    };
  } catch (error) {
    return {
      content: [
        {
          type: "text",
          text: `Error collecting items: ${error.message}`,
        },
      ],
      isError: true,
    };
  }
});
function runPowerShellPopup() {
  return new Promise((resolve, reject) => {
    const ps = spawn("powershell", [
      "-NoProfile",
      "-ExecutionPolicy", "Bypass",
      "-File", POWERSHELL_SCRIPT
    ]);
    let stdoutData = "";
    let stderrData = "";
    ps.stdout.on("data", (data) => {
      stdoutData += data.toString();
    });
    ps.stderr.on("data", (data) => {
      stderrData += data.toString();
    });
    ps.on("close", (code) => {
      // Non-zero exit code usually means error or forced kill, but we'll check stdout first.
      // If user cancels via button, script exits with 0 but prints nothing (or empty).
      
      if (stderrData && code !== 0) {
        console.error("PS Error:", stderrData);
      }
      const trimmed = stdoutData.trim();
      if (!trimmed) {
        // Empty output = Cancel
        resolve([]);
        return;
      }
      try {
        // Parse the last line as JSON
        const lines = trimmed.split('\n');
        const lastLine = lines[lines.length - 1];
        const result = JSON.parse(lastLine);
        
        if (Array.isArray(result)) {
          resolve(result);
        } else {
          // Fallback if script returned single object instead of array (shouldn't happen with current script)
          resolve([result]);
        }
      } catch (e) {
        // If parsing fails, it might be just noise or an error
        console.error("Failed to parse output:", trimmed);
        resolve([]); // Treat as empty/fail safely
      }
    });
  });
}
const transport = new StdioServerTransport();
await server.connect(transport);
