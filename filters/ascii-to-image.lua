-- ascii-to-image.lua
-- Converts ```ascii code blocks to images using ditaa.
-- Inserts the image using raw LaTeX and raw HTML, avoiding AST conversion issues.

local function run_ditaa(content)
  -- Write ASCII content to a temporary file
  local tmp = os.tmpname() .. ".txt"
  local f = io.open(tmp, "w")
  f:write(content)
  f:close()

  -- Generate a fixed filename (so we know where to find it)
  local img_name = "ascii-diagram.png"
  local cmd = string.format("ditaa --no-antialias --png %s %s", tmp, img_name)
  os.execute(cmd)

  os.remove(tmp)

  -- Check if image was created
  local img_file = io.open(img_name, "r")
  if img_file then
    img_file:close()
    return img_name
  else
    io.stderr:write("ditaa failed to generate image\n")
    return nil
  end
end

function CodeBlock(el)
  if el.classes:includes("ascii") then
    local img_path = run_ditaa(el.text)
    if img_path then
      -- For PDF: use raw LaTeX \includegraphics (requires graphicx package, already loaded by pandoc)
      local latex = "\\includegraphics{" .. img_path .. "}"
      -- For HTML/Word: use raw HTML <img> (pandoc can convert this to DOCX images)
      local html = '<img src="' .. img_path .. '" alt="ASCII diagram" />'
      -- Return a RawBlock for both formats; pandoc will pick the appropriate one
      return {
        pandoc.RawBlock('latex', latex),
        pandoc.RawBlock('html', html)
      }
    else
      -- Fallback: keep the original code block (no image)
      return el
    end
  end
end
