# PDF Bilingual Translator Skill

Transform any PDF document into a bilingual side-by-side HTML reader with navigation, tables, and formatting preserved.

## Installation

**CodeBuddy** — project or global:

```bash
# Project-local (installs to .codebuddy/skills/)
SKILL_BASE_URL="https://github.com/qliu95114/demystify/tree/main" npx skill skills/pdf-bilingual-translator

# Global (all projects)
cp -r skills/pdf-bilingual-translator ~/.codebuddy/skills/
```

**All agents** (CodeBuddy, Claude Code, Copilot, Cursor, etc.):

```bash
# Copy to the agent's global skills directory
cp -r skills/pdf-bilingual-translator ~/.agent/skills/
# or
cp -r skills/pdf-bilingual-translator ~/.claude/skills/
```

> **Note:** `npx skills add qliu95114/demystify` is not yet supported — the `skills` CLI requires specific repo metadata. Use the manual copy method for now.

## Prerequisites

```bash
pip install PyMuPDF
```

On Windows, install [pandoc](https://pandoc.org/installing.html) and use Git Bash.

## What it does

1. **Extracts** text from PDF pages and renders high-resolution PNGs
2. **Detects** image-embedded pages and flags them for OCR
3. **Translates** content to the target language (use AI for translation)
4. **Assembles** a self-contained bilingual HTML with:
   - Left panel: Original PDF page as PNG (base64 embedded)
   - Right panel: Translated content with preserved formatting
   - Navigation toolbar with page dropdown and keyboard shortcuts

## Usage

After installation, ask your AI coding assistant:

> "Translate this French contract PDF to Chinese using the pdf-bilingual-translator skill"

> "Convert this Japanese report to English, preserving all tables"

## Skill structure

```
pdf-bilingual-translator/
├── SKILL.md                      # Skill instructions (spec-compliant)
├── README.md                     # This file
├── scripts/
│   ├── extract_pdf.py            # PDF text/image extraction
│   ├── assemble_bilingual.py     # Bilingual HTML assembly
│   └── validate.py               # HTML validation (div balance, Unicode)
└── references/
    └── navigation.md             # Navigation template (CSS/JS)
```

## Requirements

- Python 3.10+
- PyMuPDF (fitz)
- pandoc (for Markdown conversion)

## License

MIT
