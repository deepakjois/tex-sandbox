local M =  {}
local harfbuzz = require "harfbuzz"
local usedfonts = {}

M.name = function()
  return harfbuzz.name()
end

return M
