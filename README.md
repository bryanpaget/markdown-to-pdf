# LibreOffice Word to PDF

A GitHub composite Action that converts a `.docx` file to PDF using
[LibreOffice](https://www.libreoffice.org/) in headless mode.

The PDF preserves the Word document's layout, fonts, and template styling,
which is not possible with a separate Pandoc/LaTeX render.

## Usage

```yaml
- name: Convert to PDF
  uses: bryanpaget/markdown-to-pdf@main
  with:
    docx_file: "output/document.docx"
    pdf_file: "output/document.pdf"
```

> The composite action does **not** perform its own checkout or install
> LibreOffice. The calling workflow must install `libreoffice-writer` first.

## Inputs

| Input       | Required | Description                                    |
|-------------|----------|------------------------------------------------|
| `docx_file` | yes      | Path to the source Word document (.docx/.doc). |
| `pdf_file`  | yes      | Path where the resulting PDF should be written.|

## Outputs

| Output    | Description                                  |
|-----------|----------------------------------------------|
| `pdf_file`| Resolved path to the generated PDF.          |

## Requirements

- `libreoffice-writer` (install with `sudo apt-get install -y libreoffice-writer`)

## License

GPL or similar
