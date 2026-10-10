-- Java is special: use nvim-jdtls instead of generic lspconfig auto-enable.
pcall(function()
  require("lazy").load({ plugins = { "nvim-jdtls" } })
end)
require("ryanparker.java").start()
