# Architecture — what OVIM is and how it works

[← Wiki home](Home.md)

---

## 1. What it is

OVIM is a **Neovim configuration**, not a fork and not a plugin. Everything it does
is done by Neovim itself plus 31 third-party plugins, arranged and configured by
about 400 lines of Lua that live in this repo.

That distinction matters practically:

- You can read the whole thing. There is no hidden layer.
- Upgrading Neovim doesn't upgrade OVIM, and vice versa.
- Anything you dislike, you can change in a file you already have.
- Nothing here is compiled. Edit a `.lua` file, restart, see the change.

The config is **symlinked** into place rather than copied:

```
~/.config/nvim  ──▶  <repo>/<platform> IDE/nvim/
```

So the repo is the live config. Editing a file in the repo changes your editor
immediately; `git status` shows what you've changed; `git checkout` undoes it.

---

## 2. What it does

| Capability | How you notice it |
|---|---|
| **Language intelligence** | Go-to-definition, rename, references, hover docs, diagnostics — from real language servers, not guesswork |
| **Completion** | Suggestions from the language server, snippets, the current buffer, and file paths |
| **Format on save** | PHP through `phpcbf`, JS/TS/CSS/HTML/JSON/Markdown through `prettierd` |
| **Linting** | `phpcs` for PHP, `eslint_d` for JS/TS, run on save, read, and leaving insert mode |
| **Structural syntax** | Treesitter parses code into a real syntax tree; highlighting, folds and indent follow the grammar rather than regex |
| **Fuzzy finding** | Files, live grep across the project, open buffers, recent files |
| **File tree, buffer tabs, git gutter, terminal** | The usual IDE furniture |

Language coverage is deliberate rather than exhaustive: **PHP/WordPress, JavaScript,
TypeScript, JSX/TSX, Java, HTML, CSS/SCSS, JSON, XML, Lua.**

---

## 3. How it works

### 3.1 Startup, in order

Reading `init.lua` top to bottom is reading the boot sequence:

1. **Bootstrap lazy.nvim.** If the plugin manager isn't on disk, clone it. This is
   the only plugin OVIM installs by hand; lazy.nvim installs the other 30.
2. **Set options.** Line numbers (absolute + relative), 2-space expanded tabs,
   24-bit colour, always-visible sign column, 8-line scrolloff.
3. **`require("lazy").setup("plugins")`** — hand control to lazy.nvim, which reads
   every file in `lua/plugins/` and loads what's needed.
4. **Guard the treesitter runtimepath** (see §3.5).
5. **Define keymaps.** See [Keybindings](Keybindings.md).
6. **Disable the Perl and Ruby providers**, which nothing here uses. Saves a startup
   probe for interpreters you don't have.

### 3.2 Plugins: declared, then pinned

Each file in `lua/plugins/` returns a table describing plugins for one concern —
`lsp.lua`, `completion.lua`, `formatting.lua`, `telescope.lua`, and so on. lazy.nvim
reads them all and merges the result.

Two ideas do the heavy lifting:

**Lazy loading.** A plugin can declare *when* it's needed. `nvim-ts-autotag` loads
only for HTML/XML/JSX/TSX files; `nvim-colorizer` waits for `BufReadPre`. On a
typical start you'll see `29/31 plugins` on the dashboard — the missing two aren't
broken, they simply haven't been needed yet.

**Version pinning.** `lazy-lock.json` records the exact commit of every plugin.
Everyone who installs from this repo gets *that* commit, not "latest". This is why a
machine set up months apart from another still behaves identically. Running
`:Lazy update` changes the lock file — that's a deliberate act, and it's a change
worth committing and testing like any other.

### 3.3 The language-server pipeline

Four pieces, each with one job:

```
mason.nvim            downloads and installs language server binaries
      ↓
mason-lspconfig       ensures the 8 servers we want are installed
      ↓
nvim-lspconfig        supplies the correct launch command and settings per server
      ↓
Neovim's built-in LSP client   talks the protocol, provides gr* keymaps and diagnostics
      ↓
cmp-nvim-lsp          feeds the server's completions into nvim-cmp
```

The eight servers and the runtime each needs:

| Server | Language | Needs |
|---|---|---|
| `jdtls` | Java | a JDK (21+) on PATH |
| `ts_ls` | JavaScript / TypeScript | Node |
| `intelephense` | PHP | Node — *not* PHP; it's a Node server |
| `lua_ls` | Lua | nothing (prebuilt binary) |
| `html`, `cssls`, `jsonls` | markup, styles, JSON | Node |
| `emmet_language_server` | Emmet expansion | Node |

**WordPress:** `lsp.lua` extends intelephense with the `wordpress`,
`wordpress-globals` and `wp-cli` stubs, so `add_action`, `$wpdb`, `WP_Query` and
friends resolve instead of showing as undefined.

### 3.4 Formatting and linting — the part that trips people up

conform.nvim (format) and nvim-lint (lint) do **not** use Mason. They look for their
tools on your `PATH`:

| Tool | Comes from | Used for |
|---|---|---|
| `prettierd` | npm global | js, jsx, ts, tsx, css, scss, html, json, jsonc, markdown |
| `eslint_d` | npm global | js, jsx, ts, tsx |
| `phpcbf` | Composer global | PHP formatting |
| `phpcs` | Composer global | PHP linting |

If they're not on `PATH`, **nothing fails loudly** — format-on-save just quietly does
nothing. That is the single most common "it's broken" report, and it is almost always
a `PATH` problem, usually because Composer's global bin directory isn't exported.
`:checkhealth conform` tells you the truth in one line.

Format-on-save uses `lsp_format = "fallback"`: the dedicated formatter runs if there
is one, otherwise the language server formats. Timeout is 2 seconds.

### 3.5 Treesitter, and one sharp edge

nvim-treesitter is pinned to its **`main` branch**, which works differently from the
`master` branch most tutorials describe:

- `main` ships only parsers and queries. Highlighting comes from Neovim itself.
- Parsers are installed explicitly with `require("nvim-treesitter").install({...})`,
  not through a `setup({ ensure_installed = ... })` table.
- Building parsers requires the **tree-sitter CLI** and a C compiler as system
  dependencies.

`treesitter.lua` then starts treesitter for any buffer whose language has a parser,
via a `FileType` autocommand guarded with `pcall`.

**The sharp edge:** parsers *and their queries* install into
`stdpath("data")/site`, which must be in `runtimepath`. lazy.nvim rewrites
`runtimepath` at startup, and on at least one Neovim version that directory didn't
survive. The symptom is nasty because it isn't an error: parsers load, but every
query — highlights, folds, indents, injections — is silently missing, so treesitter
looks installed and nothing is highlighted. `init.lua` now appends the path if it's
absent. `:checkhealth nvim-treesitter` shows `is in runtimepath` when healthy.

### 3.6 Completion

nvim-cmp draws from four sources, in priority order: the language server, LuaSnip
snippets, words in the current buffer, and filesystem paths. `<C-Space>` opens the
menu; `<CR>` confirms the selected entry. nvim-autopairs closes brackets and quotes
alongside it.

### 3.7 The dashboard

snacks.nvim renders the start screen. Everything else snacks offers is deliberately
**disabled**, because each would duplicate or fight a plugin already in the config —
its file explorer against nvim-tree, its picker against Telescope, its terminal
against toggleterm, its statuscolumn against gitsigns.

The logo adapts to your terminal. Where the Kitty graphics protocol is available
(kitty, ghostty, wezterm) it draws the real PNG; everywhere else — iTerm2, Terminal.app,
GNOME Terminal — it falls back to pre-rendered ANSI block art. Both files are in
`assets/`, and the command that regenerates the ANSI art is in the comments of
`dashboard.lua`.

The bottom line is a live health signal:

```
⚡ Neovim v0.12.5 · 29/31 plugins in 64.11ms
```

Neovim's version, plugins loaded out of total, and actual startup time.

### 3.8 Versioning

`lua/oncilla/version.lua` holds the version as data, and the dashboard reads it. One
source of truth, so the displayed version cannot drift from the tagged one — provided
the `version.lua` edit and the git tag ride in the same commit.

---

## 4. Where things live on disk

| Path | Contents |
|---|---|
| `~/.config/nvim` | symlink → this repo's config |
| `~/.local/share/nvim` | plugins, Mason servers, treesitter parsers |
| `~/.local/state/nvim` | undo history, swap, shada, logs |
| `~/.cache/nvim` | caches |

Only the first is version-controlled. The other three are rebuildable — deleting them
costs you a few minutes of re-installation and nothing else. That makes them the
first thing to move aside when the editor misbehaves in a way the config can't
explain.

Under `NVIM_APPNAME=<name>` (the installer's side-by-side mode) all four paths shift
to that name at once, which is what makes two parallel installs genuinely isolated.

---

## 5. Known gaps

Honest list, current as of v0.1.0:

- **Debugging is not wired up.** `nvim-dap` and `nvim-dap-ui` are installed and
  configured, but no debug *adapter* is defined for any language, so there is nothing
  to attach to. The UI opens; it just has no session.
- **gitsigns sets no keymaps.** The signs appear in the gutter, but hunk navigation,
  staging, preview and blame have no shortcuts bound. All are available as `:Gitsigns`
  commands.
- **Mason's repos moved.** `lsp.lua` references `williamboman/mason.nvim`; the project
  moved to the `mason-org` organisation. It works today through GitHub redirects.

---

[← Wiki home](Home.md) · [Installation →](Installation.md) · [Keybindings →](Keybindings.md)
