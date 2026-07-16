-- ascii-to-image.lua
-- Converts code blocks with class "ascii" to images using ditaa.
-- Returns a pandoc Image element that will be handled correctly by pandoc.

local function run_ditaa(content)
  -- Write ASCII content to a temporary file
  local tmp = os.tmpname() .. ".txt"
  local f = io.open(tmp, "w")
  f:write(content)
  f:close()

  -- Generate a unique image name (PNG)
  local outfile = os.tmpname() .. ".png"
  local cmd = string.format("ditaa --no-antialias --png %s %s", tmp, outfile)
  os.execute(cmd)

  -- Clean up temporary text file
  os.remove(tmp)

  -- Check if image was created
  if not io.open(outfile, "r") then
    io.stderr:write("ditaa failed to generate image\n")
    return nil
  end

  return outfile
end

function CodeBlock(el)
  if el.classes:includes("ascii") then
    local img_path = run_ditaa(el.text)
    if img_path then
      -- Return a pandoc Image with empty caption; the image will be embedded
      local img = pandoc.Image({}, img_path)
      return img
    else
      -- Fallback: return the original code block as plain text (with a warning)
      io.stderr:write("Warning: ascii diagram conversion failed, keeping original code.\n")
      return el
    end
  end
end
