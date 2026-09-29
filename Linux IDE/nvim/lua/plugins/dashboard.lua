return {
  {
    "folke/snacks.nvim",
    version = "*",
    priority = 1000,
    lazy = false,
    config = function()
      -- Resolve this config directory from the location of *this file*, so the
      -- asset paths keep working on any clone, wherever the repo lives on disk.
      -- <root>/lua/plugins/dashboard.lua -> <root>
      local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
      if vim.fn.isdirectory(root .. "/assets") == 0 then
        root = vim.fn.stdpath("config")
      end

      local logo_image = root .. "/assets/Oncilla_T.png"
      local logo_ansi = root .. "/assets/oncilla-logo.ans"

      -- Size of assets/oncilla-logo.ans, in terminal cells.
      --
      -- Regenerate with (font-ratio = this terminal's cell width/height, from
      -- `:checkhealth snacks` -> Terminal Dimensions; iTerm2 here reports 14x32):
      --   chafa assets/Oncilla_T.png --format symbols --symbols block+space \
      --     --size 30x40 --colors full --animate off --polite on --font-ratio 0.4375
      local logo_width, logo_height = 30, 14

      -- Wide enough for the menu rows and the tagline; the logo is narrower and
      -- gets centred inside it via `indent` below.
      local dash_width = 42
      local logo_indent = math.floor((dash_width - logo_width) / 2)

      -- The PNG is only used when snacks can genuinely draw it: that needs a
      -- terminal speaking the Kitty graphics protocol (kitty / ghostty / wezterm).
      -- Anything else -- iTerm2 included -- falls through to the ANSI art.
      local function image_supported()
        return vim.fn.filereadable(logo_image) == 1
          and Snacks.image.supports_file(logo_image)
          and Snacks.image.supports_terminal()
      end

      -- Header: either the real PNG anchored into the dashboard buffer, or the
      -- pre-rendered block art piped through a dashboard terminal section.
      local function logo_section()
        if not image_supported() then
          return {
            section = "terminal",
            cmd = "cat " .. vim.fn.shellescape(logo_ansi),
            height = logo_height,
            width = logo_width,
            indent = logo_indent,
            padding = 1,
          }
        end

        return function(self)
          -- The item's screen position is only known once the dashboard has laid
          -- itself out, so anchor the image after that has happened. `inline`
          -- lets snacks reserve the rows it needs itself, so the anchor below is
          -- a single line rather than a hand-counted block.
          vim.api.nvim_create_autocmd("User", {
            pattern = "SnacksDashboardUpdatePost",
            once = true,
            callback = function()
              local item = vim.tbl_filter(function(it)
                return it.oncilla_logo and it._
              end, self.items)[1]
              if not item then
                return
              end
              Snacks.image.placement.new(self.buf, logo_image, {
                pos = { item._.row, item._.col },
                width = logo_width,
                inline = true,
                auto_resize = true,
              })
            end,
          })

          return {
            oncilla_logo = true,
            padding = 1,
            align = "center",
            text = { { (" "):rep(logo_width) } },
          }
        end
      end

      local oncilla = require("oncilla.version")

      -- Last line of the dashboard: which Neovim is underneath, and what lazy
      -- actually loaded. Mirrors snacks' own `startup` section, with the Neovim
      -- version folded in so the whole runtime story sits on one row.
      local function runtime_section()
        local v = vim.version()
        local stats = require("lazy.stats").stats()
        local ms = math.floor(stats.startuptime * 100 + 0.5) / 100

        return {
          align = "center",
          text = {
            { ("⚡ Neovim v%d.%d.%d"):format(v.major, v.minor, v.patch), hl = "footer" },
            { " · ", hl = "footer" },
            { stats.loaded .. "/" .. stats.count, hl = "special" },
            { " plugins in ", hl = "footer" },
            { ms .. "ms", hl = "special" },
          },
        }
      end

      require("snacks").setup({
        dashboard = {
          width = dash_width,
          preset = {
            keys = {
              { icon = " ", key = "f", desc = "Find Files",    action = ":Telescope find_files" },
              { icon = " ", key = "g", desc = "Live Grep",     action = ":Telescope live_grep" },
              { icon = " ", key = "r", desc = "Recent Files",  action = ":Telescope oldfiles" },
              { icon = "󰈚 ", key = "b", desc = "Buffers",       action = ":Telescope buffers" },
              { icon = " ", key = "e", desc = "File Explorer", action = ":NvimTreeToggle" },
              { icon = " ", key = "q", desc = "Quit",          action = ":qa" },
            },
          },
          sections = {
            logo_section(),
            {
              align = "center",
              text = {
                { "OVIM", hl = "header" },
                { " — Oncilla IDE", hl = "footer" },
                { "  v" .. oncilla.string(), hl = "special" },
              },
            },
            {
              align = "center",
              padding = 1,
              text = { { "Technology for Ministry", hl = "footer" } },
            },
            -- gap = 0 keeps the whole dashboard inside a ~26 row window;
            -- with gap = 1 the footer scrolls off on short terminals.
            { section = "keys", gap = 0, padding = 1 },
            runtime_section,
          },
        },

        -- Only the dashboard is wanted for now. Everything that would otherwise
        -- duplicate or fight an existing plugin stays off.
        bigfile      = { enabled = false },
        dim          = { enabled = false },
        explorer     = { enabled = false }, -- nvim-tree
        indent       = { enabled = false },
        input        = { enabled = false },
        notifier     = { enabled = false },
        picker       = { enabled = false }, -- telescope
        quickfile    = { enabled = false },
        scope        = { enabled = false },
        scroll       = { enabled = false },
        statuscolumn = { enabled = false }, -- gitsigns owns the sign column
        terminal     = { enabled = false }, -- toggleterm
        words        = { enabled = false },
        -- The dashboard calls the image API directly, so no buffer hooks needed.
        image        = { enabled = false, doc = { enabled = false } },
      })
    end,
  },
}
