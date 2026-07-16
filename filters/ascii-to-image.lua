-- ascii-to-image.lua
-- Converts code blocks with class "ascii" to images using ditaa.
--
-- NOTE: pandoc 3.7.0.2's `pandoc.Image(...)` constructor throws an internal
-- "__toinline" error, so we build the Image AST node via a plain table.

local function run_ditaa(content)
  -- Write ASCII content to a temporary file
  local tmp = os.tmpname() .. ".txt"
  local f = io.open(tmp, "w")
  f:write(content)
  f:close()

  -- Generate a unique image name (PNG)
  local outfile = os.tmpname() .. ".png"
  -- ditaa <input> <output>; extra flags are optional and noisy.
  local cmd = string.format("ditaa %s %s", tmp, outfile)
  os.execute(cmd)

  -- Remove temporary text file
  os.remove(tmp)
  return outfile
end

function CodeBlock(el)
  if el.classes:includes("ascii") then
    local img_path = run_ditaa(el.text)
    -- Build the Image node as an AST table (works around the pandoc 3.7
    -- Image() constructor bug).
    return {
      t = "Image",
      attr = { identifier = "", classes = {}, attributes = {} },
      caption = { t = "Inlines", {} },
      target = { t = "Target", url = img_path, title = "" }
    }
  end
end
