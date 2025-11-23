#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";
import { spawn } from "child_process";
import path from "path";
import { fileURLToPath } from "url";
import fs from "fs";
// Setup paths
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const POWERSHELL_SCRIPT = path.join(__dirname, "..", "powershell", "PastePopup.ps1");
const DEBUG_LOG = path.join(__dirname, "..", "debug.log");

function debugLog(msg) {
  const timestamp = new Date().toISOString();
  fs.appendFileSync(DEBUG_LOG, `[${timestamp}] ${msg}\n`);
}
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
        description: "Opens a Windows popup to let the user paste images, Excel tables, rich text, or plain text from their clipboard. Use this when the user indicates they want to attach content (e.g. via @pic).",
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
  debugLog("=== Tool called: collect_pasted_items ===");
  try {
    const items = await runPowerShellPopup();
    debugLog(`Received ${items.length} items from popup`);
    
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
    // Group items by type
    const images = items.filter(i => i.type === "image");
    const tables = items.filter(i => i.type === "table");
    const richtext = items.filter(i => i.type === "richtext");
    const text = items.filter(i => i.type === "text");

    // Build friendly summary
    const parts = [];
    if (images.length > 0) {
      parts.push(`${images.length} image${images.length > 1 ? 's' : ''}`);
    }
    if (tables.length > 0) {
      parts.push(`${tables.length} table${tables.length > 1 ? 's' : ''}`);
    }
    if (richtext.length > 0) {
      parts.push(`${richtext.length} rich text item${richtext.length > 1 ? 's' : ''}`);
    }
    if (text.length > 0) {
      parts.push(`${text.length} text item${text.length > 1 ? 's' : ''}`);
    }

    const count = items.length;
    const itemNames = items.map(i => i.name).join(", ");
    const summaryText = `[${parts.join(', ')} attached: ${itemNames}]`;

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
    ], {
      // Ensure proper encoding
      env: { ...process.env, PYTHONIOENCODING: 'utf-8' }
    });
    let stdoutData = "";
    let stderrData = "";
    ps.stdout.on("data", (data) => {
      stdoutData += data.toString();
    });
    ps.stderr.on("data", (data) => {
      stderrData += data.toString();
    });
    ps.on("close", (code) => {
      debugLog(`Exit code: ${code}`);
      debugLog(`stdout length: ${stdoutData.length}`);
      debugLog(`stdout: ${stdoutData.substring(0, 1000)}`);
      debugLog(`stderr: ${stderrData}`);

      if (stderrData && code !== 0) {
        debugLog(`PS Error: ${stderrData}`);
      }
      const trimmed = stdoutData.trim();
      if (!trimmed) {
        debugLog("Empty output, resolving []");
        resolve([]);
        return;
      }
      try {
        const lines = trimmed.split('\n');
        const lastLine = lines[lines.length - 1].trim();
        debugLog(`Parsing last line: ${lastLine.substring(0, 500)}`);
        const result = JSON.parse(lastLine);

        if (Array.isArray(result)) {
          debugLog(`Parsed array with ${result.length} items`);
          resolve(result);
        } else {
          debugLog("Parsed single object, wrapping in array");
          resolve([result]);
        }
      } catch (e) {
        debugLog(`Parse error: ${e.message}`);
        debugLog(`Raw output: ${trimmed}`);
        resolve([]);
      }
    });
  });
}
const transport = new StdioServerTransport();
await server.connect(transport);
