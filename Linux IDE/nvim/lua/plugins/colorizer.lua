return {
  {
    "catgoose/nvim-colorizer.lua",
    event = "BufReadPre",
    config = function()
      require("colorizer").setup({
        filetypes = { "css", "scss", "html", "javascriptreact", "typescriptreact", "javascript" },
        user_default_options = { css = true, tailwind = false },
      })
    end,
  },
}
