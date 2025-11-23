# Project Progress - Claude Paste MCP

## Last Updated: 2024-11-24

---

## Completed Phases

### Phase 1: Single Image Paste
- Basic popup for pasting single images
- Image saved to temp folder and returned to Claude

### Phase 2: Multi-Image Support
- Multiple images can be pasted
- List view with selection
- Delete capability
- Preview pane

### Phase 3: Tables, Rich Text, Plain Text
- Excel table detection via HTML Format clipboard
- Rich Text Format (RTF) support
- Plain text fallback
- Progress bar during paste operations
- Tabbed preview (Source / Rendered tabs)
- Git commit: `28b226b`

---

## Phase 4: Moodle Code Generation (IN PROGRESS)

### Goal
Add Moodle Code tab that auto-converts Excel tables to Moodle Cloze format:
- Red text cells = correct answers
- Numerical values: `{:NM:=value}`
- Text values: `{:MC:~="value"}`

### What's Been Done
1. **Added Moodle Code tab** - Shows generated Moodle Cloze HTML
2. **Added Moodle Preview tab** - Renders the Moodle output
3. **Added Rename button** - Users can rename pasted items (e.g., "before", "after")
4. **Fixed table detection** - Excel fragments now properly wrapped in `<table>` tags
5. **Fixed CSS selector issue** - Was matching `table {` in CSS instead of `<table>` HTML element

### Fixes Applied (latest session)
- Changed `<table` check to `<table[\s>]` to match HTML elements only
- Extract `<tr>...</tr>` rows separately and wrap in `<table>`
- Preserve Excel style blocks for red color detection
- Search ALL style blocks for red classes (not just first)
- Added inline style detection (`style="color:red"`, `<font color=red>`)

### Still Needs Testing
- **Rendered tab** - Should now show formatted table (not plain text)
- **Moodle Code tab** - Should generate clean table (not "No table found")
- **Red text detection** - Need to test with Excel cells that have red font color
- **Rename feature** - Dialog should appear when clicking Rename button

### Key Files
- `powershell/PastePopup.ps1` - Main popup script with all the logic
- `src/index.js` - MCP server

---

## Pending Phases

### Phase 5: Integrate /pic MCP into Learn Editor
- Location: `D:\ai_testing\Learn editor\learn-editor\`
- GitHub: https://github.com/G3sparky/learn-editor (private)
- Goal: Allow Learn Editor to use /pic for pasting tables

### Phase 6: Red-text Answer Detection for Multiple Choice
- Detect red text in Word documents
- Convert to multiple choice Moodle format

### Phase 7: Add Multiple Choice to Learn Editor
- Expand Learn Editor to support multiple choice questions

---

## Related Projects

### Learn Editor
- Location: `D:\ai_testing\Learn editor\learn-editor\`
- GitHub: https://github.com/G3sparky/learn-editor (private)
- Purpose: Moodle Learn Editor for creating electrical assessment tables

### Moodle Cloze Format Reference
- Numerical: `{:NM:=value}` or `{:NM:=value:tolerance}`
- Multiple Choice: `{:MC:~option1~option2~=correct~option3}`
- Templates at: `D:\ai_testing\Learn editor\Tempplates compleated\CASE STUDY 1\`

---

## Next Steps (for tomorrow)
1. Test the popup with an Excel table that has RED text cells
2. Verify Rendered tab shows formatted table
3. Verify Moodle Code generates proper output with `{:NM:=value}` for red cells
4. Test Rename feature
5. Once Phase 4 is working, commit and move to Phase 5
