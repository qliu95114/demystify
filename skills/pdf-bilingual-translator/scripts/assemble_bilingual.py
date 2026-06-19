# -*- coding: utf-8 -*-
"""Assemble bilingual HTML from page PNGs and translated Markdown files.

Usage: python assemble_bilingual.py <page_count> <output.html>
"""
import base64, os, re, sys, subprocess


def md_to_html(md_text):
    """Convert Markdown to HTML using pandoc."""
    result = subprocess.run(
        ["pandoc", "-f", "markdown", "-t", "html", "--wrap=none"],
        input=md_text, capture_output=True, text=True
    )
    return result.stdout


def build_bilingual(page_count, output_html):
    """Build bilingual HTML with PNG left, translation right."""
    pages = []

    for p in range(1, page_count + 1):
        # Load PNG
        png_name = f"page_{p:03d}.png"
        if os.path.exists(png_name):
            with open(png_name, "rb") as f:
                b64 = base64.b64encode(f.read()).decode()
            img_src = f"data:image/png;base64,{b64}"
        else:
            img_src = ""

        # Load translation
        md_name = f"translated/page_{p:03d}.md"
        if os.path.exists(md_name):
            with open(md_name, "r", encoding="utf-8") as f:
                md_content = f.read()
            right_html = md_to_html(md_content)
        else:
            right_html = f"<p>Page {p} - No translation available</p>"

        pages.append(f'''<div class="page-pair" id="page{p}">
  <div class="left-panel">
    <img src="{img_src}" alt="Page {p}">
    <div class="caption">Page {p} — Français (原件)</div>
  </div>
  <div class="right-panel">{right_html}</div>
</div>''')

    # Build full HTML
    html = f'''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<title>Bilingual Contract</title>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{ font-family: "Microsoft YaHei", sans-serif; background: #f0f0f0; }}
  .toolbar {{
    position: fixed; top: 0; left: 0; right: 0; z-index: 100;
    background: #1a1a2e; color: white; padding: 12px 24px;
    display: flex; align-items: center; gap: 12px;
  }}
  .toolbar select {{ padding: 4px 8px; font-size: 13px; }}
  .toolbar .nav-btn {{
    padding: 6px 16px; background: #e94560; color: white; border: none;
    border-radius: 4px; cursor: pointer;
  }}
  .page-container {{ margin-top: 56px; padding: 20px; }}
  .page-pair {{ display: none; max-width: 1800px; margin: 0 auto; }}
  .page-pair.active {{ display: flex; gap: 20px; }}
  .left-panel {{ flex: 0 0 48%; background: white; padding: 10px; border-radius: 4px; }}
  .left-panel img {{ width: 100%; }}
  .left-panel .caption {{ text-align: center; padding: 8px; font-size: 12px; color: #666; }}
  .right-panel {{ flex: 0 0 48%; background: white; padding: 40px; border-radius: 4px; overflow-y: auto; max-height: calc(100vh - 100px); }}
  @media (max-width: 1000px) {{
    .page-pair.active {{ flex-direction: column; }}
    .right-panel {{ max-height: none; }}
  }}
</style>
</head>
<body>
<div class="toolbar">
  <span>Contract | Contrat</span>
  <select id="pageSelect" onchange="showPage(+this.value.replace('page',''))">
    {"".join(f'<option value="page{i}">Page {i}</option>' for i in range(1, page_count+1))}
  </select>
  <button class="nav-btn" onclick="prevPage()">Prev</button>
  <button class="nav-btn" onclick="nextPage()">Next</button>
  <span class="info" id="pageIndicator">Page 1 / {page_count}</span>
</div>
<div class="page-container">
{"".join(pages)}
</div>
<script>
  let currentPage = 1;
  const totalPages = {page_count};
  function showPage(n) {{
    document.querySelectorAll('.page-pair').forEach(el => el.classList.remove('active'));
    document.getElementById('page' + n).classList.add('active');
    document.getElementById('pageSelect').value = 'page' + n;
    document.getElementById('pageIndicator').textContent = 'Page ' + n + ' / ' + totalPages;
    currentPage = n;
    window.scrollTo({{top: 0, behavior: 'smooth'}});
  }}
  function nextPage() {{ if (currentPage < totalPages) showPage(currentPage + 1); }}
  function prevPage() {{ if (currentPage > 1) showPage(currentPage - 1); }}
  document.addEventListener('keydown', function(e) {{
    if (e.key === 'ArrowRight') nextPage();
    if (e.key === 'ArrowLeft') prevPage();
  }});
  showPage(1);
</script>
</body>
</html>'''

    with open(output_html, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"Assembled {page_count} pages to {output_html}")


if __name__ == "__main__":
    page_count = int(sys.argv[1]) if len(sys.argv) > 1 else 41
    output = sys.argv[2] if len(sys.argv) > 2 else "bilingual.html"
    build_bilingual(page_count, output)
