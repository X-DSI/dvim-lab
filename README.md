# dVIM — DSI IDE

A curated, version-controlled Neovim IDE for DSI development work: PHP and
WordPress, JavaScript/TypeScript, Java, and web front-end.

dVIM is **not a fork of Neovim**. It is a configuration — a set of Lua files and a
pinned plugin list — plus an installer that reproduces the whole environment on a
fresh machine. You still run Neovim; `dvim` is just the name it answers to.

---

![dVIM editing its own init.lua: the file tree on the left, a buffer tab across the
top, treesitter-highlighted Lua in the main window, LSP diagnostic markers in the
gutter and a warning count in the statusline, and a zsh terminal split across the
bottom](docs/screenshots/editor.png)

The file tree, buffer tabs, treesitter highlighting, live LSP diagnostics, the
lualine status bar and an integrated terminal — all from the config in this repo.

---

## Repository layout

```
vim-ide/
├── macOS IDE/
│   ├── bootstrap-macos.sh    interactive installer for macOS
│   ├── SETUP.md              macOS setup and dependency manifest
│   └── nvim/                 the config (symlinked to ~/.config/nvim)
├── Linux IDE/
│   ├── bootstrap-linux.sh    interactive installer for Debian/Ubuntu
│   ├── SETUP.md              Linux setup and dependency manifest
│   └── nvim/                 the same config
└── (wiki)                    full documentation — see the project Wiki
```

The two `nvim/` trees are **byte-identical**. Only the installers differ, because
macOS and Linux disagree about almost everything below the editor.

## What's inside

| Area               | Provided by                                                            |
| ------------------ | ---------------------------------------------------------------------- |
| Plugin management  | lazy.nvim, pinned in `lazy-lock.json`                                  |
| Language servers   | Mason — jdtls, ts_ls, intelephense, lua_ls, html, cssls, jsonls, emmet |
| Completion         | nvim-cmp + LuaSnip                                                     |
| Syntax / structure | nvim-treesitter (`main` branch)                                        |
| Formatting         | conform.nvim — prettierd, phpcbf                                       |
| Linting            | nvim-lint — eslint_d, phpcs                                            |
| Finding            | Telescope + ripgrep + fd                                               |
| Files / buffers    | nvim-tree, bufferline                                                  |
| Git                | gitsigns                                                               |
| Terminal           | toggleterm                                                             |
| Dashboard          | snacks.nvim                                                            |

PHP support is tuned for WordPress: intelephense is configured with the WordPress,
`wordpress-globals` and `wp-cli` stubs.
