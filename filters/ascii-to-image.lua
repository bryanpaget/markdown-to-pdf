-- ascii-to-image.lua
-- Converts code blocks with class "ascii" to images using ditaa.
-- Images are inserted into the pandoc media bag for reliable embedding.

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
  local img_file = io.open(outfile, "r")
  if not img_file then
    io.stderr:write("ditaa failed to generate image\n")
    return nil
  end
  img_file:close()

  return outfile
end

function CodeBlock(el)
  if el.classes:includes("ascii") then
    local img_path = run_ditaa(el.text)
    if img_path then
      -- Read the image file and insert into media bag
      local f = io.open(img_path, "rb")
      if not f then
        io.stderr:write("Could not read generated image\n")
        return el
      end
      local data = f:read("*all")
      f:close()
      os.remove(img_path)  -- clean up temporary file

      -- Generate a unique name for the media bag
      local ext = "png"
      local name = "ascii-" .. os.time() .. "." .. ext
      pandoc.mediabag.insert(name, "image/png", data)

      -- Return a block element: a paragraph containing the image
      local img = pandoc.Image({}, pandoc.mediabag.name_to_path(name))
      return pandoc.Para({img})
    else
      -- Fallback: keep the original code block
      io.stderr:write("Warning: ascii diagram conversion failed, keeping original code.\n")
      return el
    end
  end
end
