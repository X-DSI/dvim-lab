return {
  "akinsho/bufferline.nvim",
  version = "*",
  dependencies = "nvim-tree/nvim-web-devicons",
  config = function()
    require("bufferline").setup({
      options = {
        mode = "buffers",
        -- circled numbers ①②③ to match the SpaceVim look
        numbers = function(opts)
          local circled = { "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨", "⑩" }
          return circled[opts.ordinal] or tostring(opts.ordinal)
        end,
        separator_style = "slant", -- arrow/angled separators; try "slope" too
        diagnostics = "nvim_lsp",  -- show LSP errors on the buffer tabs
        show_buffer_close_icons = true,
        show_close_icon = false,
        -- keep the tabline aligned next to nvim-tree instead of overlapping it
        offsets = {
          {
            filetype = "NvimTree",
            text = "File Explorer",
            highlight = "Directory",
            separator = true,
          },
        },
      },
    })
  end,
}
