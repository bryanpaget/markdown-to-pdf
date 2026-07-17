-- ascii-to-image.lua
-- Converts ```ascii blocks to PNG via ditaa, centered with a border.

local function run_ditaa(content)
  local tmp = os.tmpname() .. ".txt"
  local f = io.open(tmp, "w")
  f:write(content)
  f:close()

  local outfile = os.tmpname() .. ".png"
  local cmd = string.format("ditaa --no-antialias --png %s %s", tmp, outfile)
  os.execute(cmd)
  os.remove(tmp)

  local img = io.open(outfile, "r")
  if img then
    img:close()
    return outfile
  end
  return nil
end

function CodeBlock(el)
  if el.classes:includes("ascii") then
    local img_path = run_ditaa(el.text)
    if img_path then
      local f = io.open(img_path, "rb")
      if not f then
        return el
      end
      local data = f:read("*all")
      f:close()
      os.remove(img_path)

      local name = "ascii-" .. os.time() .. ".png"
      pandoc.mediabag.insert(name, "image/png", data)
      local img = pandoc.Image({}, pandoc.mediabag.name_to_path(name))

      -- Wrap in a centered, bordered box
      local latex = string.format([[
\begin{center}
\fbox{\includegraphics[width=0.8\textwidth]{%s}}
\end{center}
]], pandoc.mediabag.name_to_path(name))

      -- Return a RawBlock for LaTeX (safe inside body)
      return pandoc.RawBlock('latex', latex)
    else
      return el
    end
  end
end
