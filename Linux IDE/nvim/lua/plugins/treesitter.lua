return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    lazy = false,
    config = function()
      -- On the `main` branch nvim-treesitter only ships parsers and queries.
      -- `setup()` takes no `ensure_installed`/`highlight` any more: parsers are
      -- installed explicitly, and highlighting comes from Neovim itself.
      require("nvim-treesitter").install({
        "lua", "java", "typescript", "tsx", "javascript", "php",
        "html", "css", "scss", "json", "xml",
      })

      -- Start treesitter for any buffer whose language has a parser available,
      -- including the ones Neovim bundles. Errors when there is no parser, so
      -- the call is guarded rather than gated on a filetype list.
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("treesitter_highlight", { clear = true }),
        callback = function(ev)
          pcall(vim.treesitter.start, ev.buf)
        end,
      })
    end,
  },
}
