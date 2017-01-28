tex.outputmode = 1

-- Build a simple paragraph node from given text. This code does not do any complex shaping etc.
--
-- adapted from: http://tex.stackexchange.com/questions/114568/can-i-create-a-node-list-from-some-text-entirely-within-lua
local function text_to_paragraph(text)
  local current_font = font.current()
  local font_params = font.getfont(current_font).parameters

  local para_head = node.new("local_par")

  local last = para_head

  local indent = node.new("hlist",3)
  indent.width = tex.parindent
  indent.dir = "TRT"
  last.next = indent
  last = indent

  for c in text:gmatch"." do  -- FIXME use utf8 lib
    local v = string.byte(c)
    local n
    if v < 32 then
      goto skipchar
    elseif v == 32 then
      n = node.new("glue",13)
      node.setglue(n, font_params.space, font_params.space_shrink, font_params.space_stretch)
    else
      n = node.new("glyph", 1)
      n.font = current_font
      n.char = v
      n.lang = tex.language
      n.uchyph = 1
      n.left = tex.lefthyphenmin
      n.right = tex.righthyphenmin
    end
    last.next = n
    last = n
    ::skipchar::
  end

  -- now add the final parts: a penalty and the parfillskip glue
  local penalty = node.new("penalty", 0)
  penalty.penalty = 10000

  local parfillskip = node.new("glue", 14)
  parfillskip.stretch = 2^16
  parfillskip.stretch_order = 2

  last.next = penalty
  penalty.next = parfillskip

  node.slide(para_head)
  return para_head
end

local content = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

for i = 1,30 do
  local head = text_to_paragraph(content)
  -- Break the paragraph into vertically stacked boxes
  local vbox = tex.linebreak(head, { hsize = tex.hsize })
  node.write(vbox)
  node.write(node.copy(tex.parskip))
  node.write(node.copy(tex.baselineskip))
  print("PAGE TOTAL " .. tex.pagetotal)
end