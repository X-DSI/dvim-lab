return {
  {
    "williamboman/mason.nvim",
    config = function() require("mason").setup() end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "neovim/nvim-lspconfig" },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {
          "jdtls", "ts_ls", "intelephense", "lua_ls",
          "html", "cssls", "jsonls", -- added for WP theme/HTML/CSS work
          "emmet_language_server",   -- Emmet expansion for HTML/CSS/JSX
        },
      })

      -- Extend the bundled intelephense config with WordPress stubs
      vim.lsp.config("intelephense", {
        settings = {
          intelephense = {
            stubs = {
              "apache", "bcmath", "bz2", "calendar", "Core", "ctype", "curl",
              "date", "dom", "fileinfo", "filter", "gd", "hash", "iconv", "json",
              "libxml", "mbstring", "mysqli", "openssl", "pcre", "PDO", "pdo_mysql",
              "Phar", "readline", "session", "SimpleXML", "sodium", "standard",
              "tokenizer", "xml", "xmlreader", "xmlwriter", "zip", "zlib",
              "wordpress", "wordpress-globals", "wp-cli",
            },
          },
        },
      })
    end,
  },
}
