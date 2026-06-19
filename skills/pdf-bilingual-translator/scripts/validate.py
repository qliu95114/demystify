# -*- coding: utf-8 -*-
"""HTML validation utilities for bilingual files.

Checks: div balance, garbled Unicode chars, page count, navigation JS.
"""
import re, sys


def validate_html(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    issues = []

    # 1. Div balance
    opens = len(re.findall(r'<div\b', content))
    closes = content.count('</div>')
    if opens != closes:
        issues.append(f"Div imbalance: {opens} opens vs {closes} closes (diff={opens-closes})")

    # 2. Garbled Unicode characters (U+FFFD)
    garbled = content.count('\ufffd')
    if garbled > 0:
        positions = []
        pos = 0
        for _ in range(min(garbled, 10)):
            pos = content.find('\ufffd', pos)
            if pos == -1:
                break
            ctx = content[max(0, pos-20):pos+20]
            positions.append(repr(ctx))
            pos += 1
        issues.append(f"Garbled Unicode (U+FFFD): {garbled} occurrences")
        for p in positions[:5]:
            issues.append(f"  at: {p}")

    # 3. Page count
    page_ids = re.findall(r'id="page(\d+)"', content)
    unique_pages = set(page_ids)
    from collections import Counter
    dupes = {k: v for k, v in Counter(page_ids).items() if v > 1}
    if dupes:
        issues.append(f"Duplicate page IDs: {dupes}")
    issues.append(f"Pages: {len(page_ids)} total, {len(unique_pages)} unique")

    # 4. Navigation
    if 'showPage' not in content:
        issues.append("Missing showPage navigation function")
    if 'pageSelect' not in content:
        issues.append("Missing pageSelect dropdown")

    # 5. Italic font
    italic = len(re.findall(r'font-style\s*:\s*italic', content))
    if italic > 0:
        issues.append(f"font-style:italic found ({italic}) - should be removed for French contracts")

    # 6. Page-pair malformed tags
    malformed = content.count('class="page"<')
    if malformed > 0:
        issues.append(f"Malformed page divs: {malformed}")

    if issues:
        print("Issues found:")
        for issue in issues:
            print(f"  - {issue}")
    else:
        print("All checks passed!")


def fix_garbled(filepath):
    """Remove all U+FFFD characters by finding contextual patterns and prompting for fixes."""
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    # Find all garbled areas
    positions = []
    pos = 0
    while True:
        pos = content.find('\ufffd', pos)
        if pos == -1:
            break
        # Get wider context (30 chars each side)
        before = content[max(0, pos-30):pos]
        after = content[pos+1:pos+30]
        positions.append((pos, before, after))
        pos += 1

    if not positions:
        print("No garbled characters found")
        return

    print(f"Found {len(positions)} garbled character(s):")
    for pos, before, after in positions[:20]:
        print(f"  Pos {pos}: ...{repr(before[-20:])} | {repr(after[:20])}...")
    print("\nFix manually by replacing the U+FFFD with correct Chinese characters.")


def fix_div_balance(filepath):
    """Attempt to fix div imbalance by finding unclosed/extra divs."""
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    opens = len(re.findall(r'<div\b', content))
    closes = content.count('</div>')

    if opens == closes:
        print("Div balance is perfect")
        return

    # Trace depth line by line in page-container section
    pc_start = content.find('<div class="page-container">')
    pc_end = content.find('<script>')
    section = content[pc_start:pc_end]

    depth = 0
    line_num = 0
    for line in section.split('\n'):
        line_num += 1
        line_opens = line.count('<div')
        line_closes = line.count('</div>')
        depth += line_opens - line_closes
        if depth < 0:
            print(f"Line {line_num}: depth went negative ({depth}) — extra </div>")
            print(f"  {line.strip()[:150]}")
            if depth < -3:
                print("  (stopping — too many extra closes)")
                break
        elif depth > 10:
            print(f"Line {line_num}: depth too high ({depth}) — possible unclosed <div>")

    print(f"\nFinal depth: {depth} (expected 0 for balance)")
    print(f"Total imbalance: {opens - closes}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python validate.py <html_file> [fix|balance]")
        sys.exit(1)

    cmd = sys.argv[2] if len(sys.argv) > 2 else ""
    if cmd == "fix":
        fix_garbled(sys.argv[1])
    elif cmd == "balance":
        fix_div_balance(sys.argv[1])
    else:
        validate_html(sys.argv[1])
