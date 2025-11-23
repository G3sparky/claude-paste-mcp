# Claude Paste MCP
A Windows-native MCP server that allows you to paste images (and eventually text/tables) directly into Claude via a popup interface.
## Requirements
- Windows 10/11
- Node.js 18+
- PowerShell 5.1+ (Standard on Windows)
## Setup
1.  **Install Dependencies**:
    ```bash
    npm install
    ```
2.  **Configure Claude**:
    Add the following to your `~/.claude/config.json` (create it if it doesn't exist):
    
    ```json
    {
      "mcpServers": {
        "claude-paste": {
          "command": "node",
          "args": ["C:\\path\\to\\claude-paste-mcp\\src\\index.js"]
        }
      }
    }
    ```
    *Note: Replace `C:\\path\\to\\...` with the actual absolute path to this folder.*
## Usage
1.  Open Claude CLI or Desktop.
2.  Type a prompt that triggers the tool, for example:
    > "I'm seeing a bug, here is the screenshot: @pic"
3.  A **Windows Popup** will appear.
4.  Press **Ctrl+V** to paste an image. You can paste multiple times.
5.  Click **Confirm**.
6.  Claude will receive the image paths and context.
## Phases
- **Phase 1 (MVP)**: Single image paste.
- **Phase 2 (Current)**: Multiple images, list view, delete capability.
- **Phase 3 (Planned)**: Support for Excel tables and Rich Text.
