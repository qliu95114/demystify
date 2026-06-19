# Navigation System for Bilingual HTML

The bilingual HTML reader uses a fixed toolbar with page navigation.

## Full Template

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Contract - Bilingue</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: "Microsoft YaHei", "Segoe UI", sans-serif; background: #f0f0f0; }
  
  .toolbar {
    position: fixed; top: 0; left: 0; right: 0; z-index: 100;
    background: #1a1a2e; color: white; padding: 12px 24px;
    display: flex; align-items: center; gap: 12px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.3);
  }
  .toolbar select { padding: 4px 8px; font-size: 13px; border-radius: 4px; }
  .toolbar .nav-btn {
    padding: 6px 16px; background: #e94560; color: white; border: none;
    border-radius: 4px; cursor: pointer; font-size: 13px;
  }
  .toolbar .nav-btn:hover { background: #c73a52; }
  .toolbar .info { margin-left: auto; font-size: 13px; opacity: 0.8; }
  
  .page-container { margin-top: 56px; padding: 20px; }
  .page-pair { display: none; max-width: 1800px; margin: 0 auto; }
  .page-pair.active { display: flex; gap: 20px; }
  
  .left-panel {
    flex: 0 0 48%; background: white;
    box-shadow: 0 2px 12px rgba(0,0,0,0.15);
    padding: 10px; border-radius: 4px; overflow: hidden;
  }
  .left-panel img { width: 100%; display: block; }
  .left-panel .caption {
    text-align: center; padding: 8px; font-size: 12px;
    color: #666; border-top: 1px solid #eee; margin-top: 8px;
  }
  
  .right-panel {
    flex: 0 0 48%; background: white;
    box-shadow: 0 2px 12px rgba(0,0,0,0.15);
    padding: 40px; border-radius: 4px; overflow-y: auto;
    max-height: calc(100vh - 100px); position: sticky; top: 76px;
  }
  .right-panel h1 { font-size: 22px; color: #1a1a2e; margin-bottom: 16px; padding-bottom: 8px; border-bottom: 2px solid #e94560; }
  .right-panel h2 { font-size: 18px; color: #333; margin: 16px 0 8px; }
  .right-panel h3 { font-size: 15px; color: #555; margin: 12px 0 6px; }
  .right-panel p { font-size: 14px; line-height: 1.8; margin: 6px 0; }
  .right-panel table { width: 100%; border-collapse: collapse; margin: 10px 0; font-size: 13px; }
  .right-panel table th, .right-panel table td { border: 1px solid #ddd; padding: 6px 8px; text-align: left; }
  .right-panel table th { background: #f8f8f8; font-weight: bold; }
  
  @media (max-width: 1000px) {
    .page-pair.active { flex-direction: column; }
    .left-panel, .right-panel { flex: 1 1 auto; }
    .right-panel { max-height: none; position: static; }
  }
</style>
</head>
<body>
<div class="toolbar">
  <span style="font-weight:bold;font-size:16px;">Contract | Contrat</span>
  <select id="pageSelect" onchange="showPage(+this.value.replace('page',''))">
    <option value="page1">Page 1 - Translation</option>
    <!-- ... more options ... -->
  </select>
  <button class="nav-btn" onclick="prevPage()">Previous</button>
  <button class="nav-btn" onclick="nextPage()">Next</button>
  <span class="info" id="pageIndicator">Page 1 / TOTAL</span>
</div>

<div class="page-container">
  <!-- page-pair divs go here -->
</div>

<script>
  let currentPage = 1;
  const totalPages = TOTAL;

  function showPage(n) {
    document.querySelectorAll('.page-pair').forEach(el => el.classList.remove('active'));
    const target = document.getElementById('page' + n);
    if (target) target.classList.add('active');
    document.getElementById('pageSelect').value = 'page' + n;
    document.getElementById('pageIndicator').textContent = 'Page ' + n + ' / ' + totalPages;
    currentPage = n;
    window.scrollTo({top: 0, behavior: 'smooth'});
  }
  function nextPage() { if (currentPage < totalPages) showPage(currentPage + 1); }
  function prevPage() { if (currentPage > 1) showPage(currentPage - 1); }
  document.addEventListener('keydown', function(e) {
    if (e.key === 'ArrowRight' || e.key === 'PageDown') nextPage();
    if (e.key === 'ArrowLeft' || e.key === 'PageUp') prevPage();
  });
  showPage(1);
</script>
</body>
</html>
```

## Page-pair structure

Each page uses a `page-pair` div containing left (PNG) and right (translation) panels:

```html
<div class="page-pair" id="page1">
  <div class="left-panel">
    <img src="data:image/png;base64,..." alt="Page 1">
    <div class="caption">Page 1 — Français (原件)</div>
  </div>
  <div class="right-panel">
    <!-- Translated content with optional per-page style block -->
  </div>
</div>
```

## Per-page custom CSS

Pages with custom layouts (tables, forms) include their own `<style>` block at the top of the right-panel. Use a unique class prefix to avoid conflicts:

```html
<div class="right-panel">
<style>
.page8 { font-family: "Microsoft YaHei", sans-serif; font-size: 11px; ... }
.page8 h1 { ... }
.page8 table { ... }
</style>
<div class="page8">
  <!-- custom formatted content -->
</div>
</div>
```

## Keyboard shortcuts

- `→` / `PageDown` : Next page
- `←` / `PageUp` : Previous page
