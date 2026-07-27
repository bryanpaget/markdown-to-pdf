# Markdown/Word to PDF

A GitHub composite Action that converts Markdown or Word (`.docx`/`.doc`) files
to PDF. Markdown files are first converted to `.docx` via
[Pandoc](https://pandoc.org/), then the Word document is converted to PDF using
[LibreOffice](https://www.libreoffice.org/) in headless mode.

The PDF preserves the document's layout, fonts, and template styling, which is
not possible with a separate Pandoc/LaTeX render.

## Usage

### From a Markdown file

```yaml
- name: Convert Markdown to PDF
  uses: bryanpaget/markdown-to-pdf@main
  with:
    markdown_file: "docs/readme.md"
    pdf_file: "output/readme.pdf"
```

### From a Word document

```yaml
- name: Convert Word to PDF
  uses: bryanpaget/markdown-to-pdf@main
  with:
    docx_file: "output/document.docx"
    pdf_file: "output/document.pdf"
```

## Inputs

| Input           | Required | Description                                             |
|-----------------|----------|---------------------------------------------------------|
| `docx_file`     | no       | Path to the source Word document (.docx/.doc).          |
| `markdown_file` | no       | Path to a Markdown file (auto-converted to .docx first).|
| `pdf_file`      | yes      | Path where the resulting PDF should be written.         |

Provide either `docx_file` or `markdown_file` (not both).

## Outputs

| Output    | Description                                  |
|-----------|----------------------------------------------|
| `pdf_file`| Resolved path to the generated PDF.          |

## Requirements

- `libreoffice-writer` (auto-installed if missing)
- `pandoc` (auto-installed if using `markdown_file`)

## License

GPL or similar
