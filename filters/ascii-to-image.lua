-- ascii-to-image.lua
-- Converts ```ascii code blocks to images using ditaa.
-- Embeds the image via pandoc.mediabag and returns a pandoc.Para
-- so it's placed after \begin{document}.

local function run_ditaa(content)
  local tmp = os.tmpname() .. ".txt"
  local f = io.open(tmp, "w")
  f:write(content)
  f:close()

  local outfile = os.tmpname() .. ".png"
  local cmd = string.format("ditaa --no-antialias --png %s %s", tmp, outfile)
  os.execute(cmd)
  os.remove(tmp)

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
      local f = io.open(img_path, "rb")
      if not f then
        io.stderr:write("Could not read generated image\n")
        return el
      end
      local data = f:read("*all")
      f:close()
      os.remove(img_path)

      local name = "ascii-" .. os.time() .. ".png"
      pandoc.mediabag.insert(name, "image/png", data)
      local img = pandoc.Image({}, pandoc.mediabag.name_to_path(name))
      return pandoc.Para({img})   -- ensures it's a block element in the body
    else
      return el
    end
  end
end
