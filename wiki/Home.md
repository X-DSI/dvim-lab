# OVIM Wiki

**OVIM — Oncilla IDE.** A curated Neovim configuration for Oncilla development work,
version-controlled and reproducible on any Mac or Ubuntu machine.

---

## Pages

| Page | Read it when |
|---|---|
| **[Architecture](Architecture.md)** | You want to know what OVIM actually is, what each moving part does, and how a keystroke becomes a formatted, linted, autocompleted file |
| **[Installation](Installation.md)** | You're setting up a new machine, or something broke and you need to know what the installer did |
| **[Keybindings](Keybindings.md)** | Daily driving — every shortcut, Neovim's own and the ones we added |
| *Cheatsheet* | *Planned — a one-page printable reference for Oncilla developers* |

Platform-specific dependency manifests and troubleshooting live beside their
installers: [macOS IDE/SETUP.md](../macOS%20IDE/SETUP.md) and
[Linux IDE/SETUP.md](../Linux%20IDE/SETUP.md).

---

## The 60-second version

OVIM is a set of Lua files that configure Neovim, plus a pinned list of 31 plugins,
plus an installer that provisions everything underneath. You run `ovim` (or `nvim`)
and get an editor with language servers, completion, format-on-save, linting, fuzzy
search, a file tree, git signs, and an integrated terminal.

It is **not** a fork of Neovim and **not** a plugin. It is configuration —
which means you can read all of it, and change any of it.

```
~/.config/nvim  ──symlink──▶  <repo>/<platform> IDE/nvim/
                                 ├── init.lua           options, keymaps, bootstrap
                                 ├── lazy-lock.json     exact plugin commits
                                 ├── lua/oncilla/       version module
                                 ├── lua/plugins/       one file per concern
                                 └── assets/            dashboard logo
```

---

## Conventions in these docs

- `<leader>` is the **spacebar**.
- `<C-x>` means Ctrl+x. `<CR>` is Enter. `<Esc>` is escape.
- Commands starting with `:` are typed in Neovim's command line.
- Commands in shell blocks are typed in your terminal, not in Neovim.

---

## Getting help from inside the editor

Neovim's own documentation is excellent and always matches the version you're
running. It beats searching the web.

| Command | Shows |
|---|---|
| `:help <topic>` | The manual. `:help windows`, `:help text-objects` |
| `:help` | Table of contents, if you don't know the topic |
| `:checkhealth` | Whether everything is wired up correctly |
| `:Lazy` | Plugin status |
| `:Mason` | Language server status |
| `:LspInfo` | Which server is attached to this buffer |
| `<leader>` then wait | which-key pops up the available next keys |

---

## Publishing this wiki to GitLab

GitLab wikis are a **separate git repository** from the project. To publish these
pages there:

```bash
git clone git@gitlab.com:oncilla-llc-group/vim-ide.wiki.git
cp wiki/*.md vim-ide.wiki/
cd vim-ide.wiki && git add -A && git commit -m "Publish OVIM wiki" && git push
```

GitLab uses `Home.md` as the wiki landing page, and page names come from filenames,
so the relative links between these pages keep working. Links pointing outside the
wiki (like `../macOS IDE/SETUP.md`) will not resolve there — the wiki is its own
repo — so fix those to full URLs if you publish.

Keeping the pages in this repo means they version alongside the config they
describe, which is why they live here first.
