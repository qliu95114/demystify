---
name: pdf-bilingual-translator
description: Transform any-language PDF into a bilingual side-by-side HTML reader. Extracts text, OCRs image-embedded pages, translates content using AI, preserves tables and formatting, and generates a navigable HTML with original PNG on the left and translation on the right. Use when a user needs a PDF document translated to another language with full layout preservation.
---

# PDF to Bilingual HTML Translator

Convert any PDF document into a bilingual side-by-side HTML reader: original language PNG on the left, translation on the right, with full-page navigation.

## Prerequisites

```bash
pip install PyMuPDF
```

On Windows, also install [pandoc](https://pandoc.org/installing.html) and run commands in Git Bash.

## Workflow

### Phase 1: Extract PDF content

Render all pages as PNG and extract text:

```python
import fitz  # PyMuPDF
doc = fitz.open("document.pdf")

# Render all pages as PNG at 2x resolution (readable on screen)
for i, page in enumerate(doc):
    pix = page.get_pixmap(matrix=fitz.Matrix(2, 2))
    pix.save(f"page_{i+1:03d}.png")

# Extract text with page markers
import subprocess
subprocess.run([
    "pandoc", "document.pdf", "-t", "markdown",
    "-o", "source.md"
])
```

If pandoc returns empty output (scanned PDF), fall back to PyMuPDF:

```python
for i, page in enumerate(doc):
    text = page.get_text("text")
    print(f"<!-- Page {i+1} -->\n{text}")
```

### Phase 2: Identify image-embedded pages

Flag pages with no extractable text for OCR:

```python
empty_pages = []
for i, page in enumerate(doc):
    text = page.get_text("text").strip()
    if not text:
        empty_pages.append(i + 1)
```

OCR these pages by reading the rendered PNGs. A multimodal AI model works well; alternatively use `tesseract`:

```bash
tesseract page_XXX.png page_XXX -l fra+eng  # adjust language codes
```

### Phase 3: Translate content

Split Markdown by `<!-- Page N -->` markers, translate each page independently:

```python
import re
with open("source.md", "r", encoding="utf-8") as f:
    text = f.read()

# Split: pages[0]=preamble, pages[1]=num, pages[2]=content, ...
pages = re.split(r'<!-- Page (\d+) -->', text)
```

Translate each page using AI. Provide a glossary if the document uses domain-specific terminology (legal, medical, technical).

**Pro tip**: Run multiple translation agents in parallel (4-5 per batch) for large documents. Use consistent terminology across all pages.

### Phase 4: Build bilingual HTML

Assemble the final HTML with `page-pair` divs, left PNG panels, right translated panels, and navigation.

Each page-pair follows this structure:

```html
<div class="page-pair" id="pageN">
  <div class="left-panel">
    <img src="data:image/png;base64,..." alt="Page N">
    <div class="caption">Page N — Original</div>
  </div>
  <div class="right-panel">
    <!-- Translated HTML content -->
  </div>
</div>
```

Embed PNGs as base64 to keep the HTML self-contained:

```python
import base64
with open(f"page_{p:03d}.png", "rb") as f:
    b64 = base64.b64encode(f.read()).decode()
img_src = f"data:image/png;base64,{b64}"
```

### Phase 5: Add navigation

See [references/navigation.md](references/navigation.md) for the complete template with toolbar, CSS, keyboard shortcuts, and JavaScript.

Critical navigation pattern — the dropdown value is a string like `"page14"`. Always convert to number:

```html
<!-- Correct: + prefix converts to number -->
onchange="showPage(+this.value.replace('page',''))"

<!-- Wrong: concatenates to "pagepage14" -->
onchange="showPage(this.value)"
```

### Phase 6: Custom layout for complex pages

For pages with complex tables, energy ratings, certificates, or forms, replace pandoc-generated HTML with custom HTML/CSS that matches the original layout exactly:

- **Unique CSS class per page**: Use `.page13`, `.page14`, `.page15`, etc. Never reuse a generic class — it causes style conflicts across pages.
- **Match original table structure**: Preserve `colspan`, `rowspan`, proportional column widths, and border styles.
- **Preserve section numbering and hierarchy**: Match the original document structure.
- **Right-align numeric cells**, left-align text labels.
- **Match header backgrounds**: Gray (`#d9d9d9` or `#e8e8e8`) for `<th>`.

Example custom CSS pattern:

```css
.page14 { font-family:sans-serif; font-size:9.5px; line-height:1.25; }
.page14 h1 { font-size:11px; font-weight:bold; text-align:center; background:#d9d9d9; padding:5px; border:1px solid #999; }
.page14 h3.section { font-size:9.5px; font-weight:bold; color:#003366; border-bottom:1px solid #999; }
.page14 table { width:100%; border-collapse:collapse; border:1px solid #666; }
.page14 th,.page14 td { border:1px solid #666; padding:2px 4px; font-size:8px; }
.page14 th { background:#e8e8e8; font-weight:bold; text-align:center; }
.page14 td.c { text-align:center; }
```

## Critical Rules

### 1. Position-based replacement only
**Never** use `str.replace()` on the entire file for page content. It replaces all occurrences, corrupting pages with identical patterns (e.g., empty right-panels).

```python
# Process in reverse order so positions don't shift
for p in range(last_page, first_page - 1, -1):
    start = content.find(f'id="page{p}"')
    end = content.find(f'id="page{p+1}"')
    content = content[:start] + new_page_content + content[end:]
```

### 2. Verify div balance after every edit

```python
import re
opens = len(re.findall(r'<div\b', content))
closes = content.count('</div>')
assert opens == closes, f"Div imbalance: {opens} vs {closes}"
```

### 3. Check for garbled Unicode (U+FFFD)

Multi-byte characters (CJK, accented Latin, etc.) can corrupt when passing through multiple tools:

```python
garbled = content.count('\ufffd')
if garbled:
    # Find context around each garbled character
    pos = content.find('\ufffd')
    ctx = content[max(0,pos-30):pos+30]
    print(f"Garbled at {pos}: {repr(ctx)}")
    # Fix by replacing with the correct characters
```

### 4. Remove italic font styling

Official documents and certificates rarely use italic. It often leaks from pandoc/Markdown conversion:

```python
import re
content = re.sub(r'font-style\s*:\s*italic\s*;?\s*', '', content)
content = content.replace('<em>', '').replace('</em>', '')
content = content.replace('<i>', '').replace('</i>', '')
```

### 5. Match column layout exactly

If the original has **2 columns**, the translation must use 2 columns with the same widths. Check the original PDF structure before building the HTML table layout.

### 6. Navigation dropdown: string-to-number conversion

The dropdown value is `"page14"` (string). The `showPage` function expects `14` (number):

```html
<!-- Correct -->
<select id="pageSelect" onchange="showPage(+this.value.replace('page',''))">

<!-- Wrong: causes lookup of id="pagepage14" -->
<select id="pageSelect" onchange="showPage(this.value)">
```

## Common Pitfalls

| Problem | Cause | Fix |
|---------|-------|-----|
| Navigation breaks at specific page | Extra/unbalanced `</div>` tag | Trace div depth line by line; remove orphans |
| All pages show identical content | Used `str.replace()` on empty right-panels | Use position-based replacement in reverse order |
| Garbled characters in translation | Unicode corruption during file write | Fix with `\ufffd` pattern search and replace |
| Page counter shows wrong total | Duplicate `page-container` div | Ensure exactly one container; remove duplicates |
| Dropdown doesn't work | String passed to `showPage` instead of number | Add `+` prefix: `+this.value.replace('page','')` |
| CSS styles conflict between pages | Generic class name reused across pages | Use unique class per page: `.page13`, `.page14` |

## File structure

```
output/
├── document_bilingual.html     # Final self-contained bilingual HTML
├── source.md                   # Raw Markdown extraction
├── translated/                 # Per-page Markdown translations
├── page_*.png                  # Rendered page images (keep for recovery)
└── scripts/                    # Extraction and assembly scripts
```

## Recovery strategy

If the HTML becomes corrupted during editing:

1. **Keep the original source** (pandoc HTML or extracted Markdown) — it's the recovery baseline
2. Rebuild page-by-page from source, extracting base64 PNG and content for each page
3. Re-apply custom CSS pages in reverse order using position-based replacement
4. Run `scripts/validate.py` after each batch of edits
