# OVIM — Oncilla IDE

A curated, version-controlled Neovim IDE for Oncilla development work: PHP and
WordPress, JavaScript/TypeScript, Java, and web front-end.

OVIM is **not a fork of Neovim**. It is a configuration — a set of Lua files and a
pinned plugin list — plus an installer that reproduces the whole environment on a
fresh machine. You still run Neovim; `ovim` is just the name it answers to.

![The OVIM dashboard: the Oncilla logo in ANSI block art, the title "OVIM — Oncilla
IDE v0.2.0", the tagline "Technology for Ministry", a six-item menu, and a footer
reading "Neovim v0.12.5 · 29/31 plugins in 82.67ms"](docs/screenshots/dashboard.png)

---

## What it looks like

![OVIM editing its own init.lua: the file tree on the left, a buffer tab across the
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

---

## Quick start

**macOS** (Apple Silicon, Homebrew):

```bash
git clone git@gitlab.com:oncilla-llc-group/vim-ide.git
cd vim-ide/"macOS IDE"
./bootstrap-macos.sh --dry-run     # see the plan
./bootstrap-macos.sh               # run it
```

**Ubuntu / Debian:**

```bash
cd vim-ide/"Linux IDE"
./bootstrap-linux.sh --dry-run
./bootstrap-linux.sh
```

The installer is interactive and idempotent: it checks before it installs, asks
before it changes anything, pauses after every step, and never deletes — existing
configs are moved to timestamped backups. Re-run it as often as you like.

Then launch with **`ovim`** (or `nvim` — both open the IDE).

One step cannot be scripted: set your terminal's font to **JetBrainsMono Nerd Font**,
or icons render as empty boxes.

---

## What's inside

| Area | Provided by |
|---|---|
| Plugin management | lazy.nvim, pinned in `lazy-lock.json` |
| Language servers | Mason — jdtls, ts_ls, intelephense, lua_ls, html, cssls, jsonls, emmet |
| Completion | nvim-cmp + LuaSnip |
| Syntax / structure | nvim-treesitter (`main` branch) |
| Formatting | conform.nvim — prettierd, phpcbf |
| Linting | nvim-lint — eslint_d, phpcs |
| Finding | Telescope + ripgrep + fd |
| Files / buffers | nvim-tree, bufferline |
| Git | gitsigns |
| Terminal | toggleterm |
| Dashboard | snacks.nvim |

PHP support is tuned for WordPress: intelephense is configured with the WordPress,
`wordpress-globals` and `wp-cli` stubs.

---

## Documentation

Full documentation lives in the **[project Wiki](https://gitlab.com/oncilla-llc-group/vim-ide/-/wikis/home)**.

| Page | What it covers |
|---|---|
| [Architecture](https://gitlab.com/oncilla-llc-group/vim-ide/-/wikis/Architecture) | What OVIM is, what it does, how it works |
| [Installation](https://gitlab.com/oncilla-llc-group/vim-ide/-/wikis/Installation) | The setup process, both platforms |
| [Keybindings](https://gitlab.com/oncilla-llc-group/vim-ide/-/wikis/Keybindings) | Every shortcut — Neovim's and ours |

The wiki is a separate git repository (`vim-ide.wiki.git`), so it is not part of a
clone of this project.

Platform specifics live beside each installer: [macOS](macOS%20IDE/SETUP.md),
[Linux](Linux%20IDE/SETUP.md).

---

## Versioning

OVIM follows [Semantic Versioning](https://semver.org). The number lives in
`nvim/lua/oncilla/version.lua` and is shown on the dashboard.

While the major version is `0`, the config is still finding its shape and anything
may change. `1.0.0` will be the promise that it won't, without a major bump.

Releases are tagged `vX.Y.Z`. Keep the `version.lua` edit in the same commit the tag
points at, so the dashboard can never disagree with the tag.
