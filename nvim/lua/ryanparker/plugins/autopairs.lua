-- Automatically insert matching brackets, quotes, etc.
-- (Commenting is handled by Comment.nvim; indent guides come from
-- snacks.indent.)
return {
  "windwp/nvim-autopairs",
  event = "InsertEnter",
  config = true,
}
