# -*- coding: utf-8 -*-
"""Extract PDF to page-by-page Markdown using pandoc and PyMuPDF fallback."""
import subprocess, sys, re
try:
    import fitz
except ImportError:
    import pymupdf as fitz


def extract_pdf(pdf_path, output_md="source.md"):
    """Extract text from PDF. Tries pandoc first, falls back to PyMuPDF."""
    # Method 1: pandoc
    try:
        subprocess.run([
            "pandoc", pdf_path, "-t", "markdown",
            "--extract-media=./media", "-o", output_md
        ], check=True)
        print(f"Pandoc extraction saved to {output_md}")
    except Exception as e:
        print(f"Pandoc failed: {e}, using PyMuPDF fallback")
        extract_with_pymupdf(pdf_path, output_md)


def extract_with_pymupdf(pdf_path, output_md):
    """Fallback to PyMuPDF text extraction."""
    doc = fitz.open(pdf_path)
    with open(output_md, "w", encoding="utf-8") as f:
        for i, page in enumerate(doc):
            text = page.get_text("text")
            f.write(f"\n\n<!-- Page {i+1} -->\n\n{text}")
    print(f"PyMuPDF extraction saved to {output_md}")


def render_pngs(pdf_path, output_dir="pages", zoom=2):
    """Render all PDF pages as PNG images."""
    import os
    os.makedirs(output_dir, exist_ok=True)
    doc = fitz.open(pdf_path)
    for i, page in enumerate(doc):
        pix = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom))
        pix.save(f"{output_dir}/page_{i+1:03d}.png")
    print(f"Rendered {len(doc)} pages to {output_dir}/")


if __name__ == "__main__":
    pdf = sys.argv[1] if len(sys.argv) > 1 else "input.pdf"
    extract_pdf(pdf)
    render_pngs(pdf)
