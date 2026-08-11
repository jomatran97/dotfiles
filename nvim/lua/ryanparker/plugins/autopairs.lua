-- Automatically insert matching brackets, quotes, etc.
-- (Commenting is handled by Neovim; indent guides come from snacks.indent.)
return {
  "windwp/nvim-autopairs",
  event = "InsertEnter",
  config = true,
}
