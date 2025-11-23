# Git Workflow
## Initial Setup
```bash
git init
git add .
git commit -m "Phase 1: Single image paste MVP"
git branch -M main
git remote add origin https://github.com/<USERNAME>/claude-paste-mcp.git
git push -u origin main
Phase 2: Multiple Images (Current)
We are currently on this phase.

git checkout -b feature/phase-2-multi-image
# ... (Files are already updated for this) ...
git add .
git commit -m "Phase 2: Support multiple images with list + preview + delete"
git push origin feature/phase-2-multi-image
Phase 3: Rich Content (Future)
Create branch feature/phase-3-rich-content.
Update PastePopup.ps1 to handle Clipboard::ContainsText() and GetData("HTML Format").
Update index.js to handle type: "table" or type: "text".
