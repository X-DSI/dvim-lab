return {
  { "lewis6991/gitsigns.nvim", config = function() require("gitsigns").setup() end },
  { "folke/which-key.nvim",    config = function() require("which-key").setup() end },
  { "windwp/nvim-autopairs",   config = function() require("nvim-autopairs").setup() end },
  { "numToStr/Comment.nvim",   config = function() require("Comment").setup() end },
}
