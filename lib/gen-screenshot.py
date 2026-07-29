import io
import os
import sys
from PIL import Image, ImageDraw, ImageFont
from pygments import highlight
from pygments.lexers import MarkdownLexer
from pygments.formatters import ImageFormatter
import fitz

md_path = "samples/screenshot-demo.md"
pdf_path = "samples/screenshot-demo.pdf"
if not os.path.exists(pdf_path):
    print(f"ERROR: {pdf_path} not found", file=sys.stderr)
    sys.exit(1)

md = open(md_path).read()

fmt = ImageFormatter(style="github-dark", line_numbers=True,
    font_name="DejaVu Sans Mono", font_size=13, image_pad=16,
    line_number_pad=4, line_number_bg="#161b22")
code_img = Image.open(io.BytesIO(highlight(md, MarkdownLexer(), fmt)))

doc = fitz.open(pdf_path)
page = doc[0]
pix = page.get_pixmap(dpi=100)
pdf_img = Image.frombytes("RGB", [pix.width, pix.height], pix.samples)

min_h = 450
code_h = max(code_img.height, min_h)
pdf_h = max(pdf_img.height, min_h)

code_w = int(code_img.width * code_h / code_img.height)
code_img = code_img.resize((code_w, code_h), Image.LANCZOS)
pdf_w = int(pdf_img.width * pdf_h / pdf_img.height)
pdf_img = pdf_img.resize((pdf_w, pdf_h), Image.LANCZOS)

total_w = code_w + pdf_w
total_h = code_h + 108

canvas = Image.new("RGB", (total_w, total_h), "#0d1117")
draw = ImageDraw.Draw(canvas)
font_b = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 20)
font_s = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
font_xs = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 12)

t = "Markdown Source \u2192 PDF Output"
bb = draw.textbbox((0, 0), t, font=font_b)
draw.text(((total_w-(bb[2]-bb[0]))//2, 14), t, fill="#e6edf3", font=font_b)

for lbl, left in [("screenshot-demo.md", 20), ("screenshot-demo.pdf", code_w + 20)]:
    bb2 = draw.textbbox((0, 0), lbl, font=font_s)
    draw.text((left, 52 - (bb2[3]-bb2[1])//2), lbl, fill="#8b949e", font=font_s)

canvas.paste(code_img, (0, 56))
canvas.paste(pdf_img, (code_w + 2, 56))

url = "github.com/bryanpaget/markdown-to-pdf"
bb3 = draw.textbbox((0, 0), url, font=font_xs)
draw.text(((total_w-(bb3[2]-bb3[0]))//2, total_h - 24), url, fill="#8b949e", font=font_xs)

w, h = canvas.size
canvas = canvas.resize((int(w*0.75), int(h*0.75)), Image.LANCZOS)
canvas.save("assets/screenshot-comparison.png")
print(f"Saved {int(w*0.75)}x{int(h*0.75)}")
