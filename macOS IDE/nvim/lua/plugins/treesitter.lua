return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
    config = function()
      require("nvim-treesitter.config").setup({
        ensure_installed = { "lua", "java", "typescript", "javascript", "php", "html", "css", "json", "xml" },
        highlight = { enable = true },
      })
    end,
  },
}
