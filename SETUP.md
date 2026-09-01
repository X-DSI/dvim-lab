# Oncilla IDE — Setup

A curated Neovim IDE, lazy.nvim based, versioned and reproducible on a fresh Mac.

> **On Linux?** See [SETUP-linux.md](SETUP-linux.md). The Neovim config is identical
> on both platforms; the installer and its dependencies are not.

- **Current version:** see `macOS IDE/nvim/lua/oncilla/version.lua` (the dashboard reads it from there)
- **Installer:** `macOS IDE/bootstrap-macos.sh`
- **Platform:** macOS, Apple Silicon, Homebrew. (A `Linux IDE/` config exists in this
  repo but has no installer and is not yet at feature parity.)

---

## Quick start

```bash
git clone git@gitlab.com:oncilla-llc-group/vim-ide.git
cd vim-ide/"macOS IDE"
./bootstrap-macos.sh
```

The script finds the config relative to its own location, so the repo can be cloned
anywhere. Nothing is hardcoded to a path.

### Options

| Flag | Effect |
|---|---|
| *(none)* | Normal interactive run. Asks before every change, pauses after every step. |
| `--dry-run` / `-n` | Prints every command it *would* run, executes nothing. Safe first look. |
| `--yes` / `-y` | Auto-answers every prompt with yes and skips the pauses. |
| `--mode=replace` | Pre-answers the existing-config question with option 1. |
| `--mode=sidebyside` | Pre-answers it with option 2. |
| `--help` / `-h` | Usage. |

Recommended first run on a new machine:

```bash
./bootstrap-macos.sh --dry-run     # read what it plans to do
./bootstrap-macos.sh               # then do it for real
```

### How the script behaves

- **Interactive.** Every dependency is its own step: it checks first, prints the
  detected version if present, and asks permission before installing anything.
  After each step it shows the command output and waits for you. Press `q` at any
  pause to stop cleanly with a summary.
- **Idempotent.** Re-run it as often as you like. It detects existing installs,
  never duplicates a PATH export, an alias, or a symlink, and never re-backs-up a
  config it already replaced.
- **Non-destructive.** It never deletes anything. Existing configs are *moved* to
  timestamped `.bak.YYYYMMDD-HHMMSS` folders. The only thing it removes is a
  symlink — and only the link, never the directory it points at.
- **It stops on errors.** A failed step asks whether to continue or abort rather
  than barrelling ahead.

---

## Dependency manifest

Everything below was derived from the config itself — the plugin specs, the
`formatters_by_ft` / `linters_by_ft` tables, and Mason's `ensure_installed` list —
not assumed.

### Prerequisites

| Item | Why |
|---|---|
| Xcode Command Line Tools | `cc`/`clang` to compile treesitter parsers; `git` for lazy.nvim |
| Homebrew | everything below |

### Homebrew formulae

| Formula | Needed by |
|---|---|
| `neovim` | the editor. **≥ 0.11 required** — the config uses `vim.uv` and `vim.lsp.config()` |
| `git` | lazy.nvim clones plugins |
| `ripgrep` | Telescope `live_grep` |
| `fd` | Telescope `find_files` |
| `tree-sitter` + `tree-sitter-cli` | `treesitter.lua` pins the `main` branch, which needs the CLI to fetch and build parsers |
| `node` | runtime for 5 of the 8 language servers, plus prettierd and eslint_d |
| `php` | runtime for Composer and for phpcs/phpcbf |
| `composer` | installs phpcs/phpcbf — **requires PHP first** |
| `openjdk` | the `jdtls` language server |
| `chafa` | *optional*, only to regenerate the dashboard's ANSI logo art |

### Nerd Font

`font-jetbrains-mono-nerd-font` — required by `nvim-web-devicons` (nvim-tree,
bufferline) and by the glyphs in the dashboard. Installed via Homebrew cask; no
`homebrew/cask-fonts` tap is needed any more (that tap is deprecated).

### npm globals

| Package | Needed by |
|---|---|
| `@fsouza/prettierd` | conform.nvim — formats js/ts/jsx/tsx/css/scss/html/json/jsonc/markdown |
| `eslint_d` | nvim-lint — lints js/jsx/ts/tsx |

These are **not** managed by Mason. conform and nvim-lint resolve them from `PATH`,
so if they're missing, format-on-save and linting silently do nothing.

### Composer globals

| Package | Provides | Needed by |
|---|---|---|
| `squizlabs/php_codesniffer` | `phpcs` and `phpcbf` | nvim-lint (php) and conform (php) |

Requires this line in `~/.zshrc`, or neither binary resolves:

```bash
export PATH="$HOME/.composer/vendor/bin:$PATH"
```

The installer adds it **only if absent**, and tells you if you already have
duplicates rather than adding more.

### Language servers (installed by Mason, inside Neovim)

| Server | Delivery | System runtime required |
|---|---|---|
| `jdtls` | Mason | **JDK** — `java` must be on `PATH` |
| `ts_ls` | npm | node |
| `intelephense` | npm | node (it's a Node server — PHP is *not* needed for it) |
| `html`, `cssls`, `jsonls` | npm | node |
| `emmet_language_server` | npm | node |
| `lua_ls` | prebuilt binary | none |

This is why the installer launches Neovim **last** — Mason must resolve these
against runtimes that already exist.

### The Java symlink

Homebrew's `openjdk` is keg-only, so `java` is not on `PATH` and `jdtls` fails to
start. The fix, which the installer performs after asking:

```bash
sudo ln -sfn "$(brew --prefix)/opt/openjdk/libexec/openjdk.jdk" \
             /Library/Java/JavaVirtualMachines/openjdk.jdk
```

This is the **only** step in the whole script that needs `sudo`.

---

## Handling an existing Neovim or SpaceVim config

Before touching anything config-related, the installer inspects `~/.config/nvim` and
distinguishes three states, because they need different handling:

1. **Nothing there** — clean install, no questions asked.
2. **A real directory** — it identifies the flavour where it can (SpaceVim, LazyVim,
   kickstart.nvim) and reports it.
3. **A symlink** — including one that already points at this repo, meaning the
   script has been run before. A symlink is unlinked, never `mv`-ed like a folder.

It also reports related state that affects a clean install: `~/.local/share/nvim`,
`~/.local/state/nvim`, `~/.cache/nvim`, and `~/.SpaceVim` / `~/.SpaceVim.d`.

When something exists, it stops and offers three choices:

### Option 1 — Back up and replace

Moves the existing config to `~/.config/nvim.bak.YYYYMMDD-HHMMSS`, then symlinks
this repo into `~/.config/nvim`. Plain `nvim` launches the Oncilla IDE.

It asks *separately* about the plugin/runtime data directories, because leaving
stale lazy.nvim and Mason state behind can confuse the first launch. SpaceVim's own
directories are a third, separate question — they don't conflict, so the default is
to leave them alone.

**Use this when** you're committing to the Oncilla IDE as your Neovim.

**To undo:** delete the symlink and move the backup back.

```bash
rm ~/.config/nvim
mv ~/.config/nvim.bak.YYYYMMDD-HHMMSS ~/.config/nvim
```

### Option 2 — Side-by-side under a separate app name

Leaves `~/.config/nvim` **completely untouched**. Installs this config at
`~/.config/oncilla` and adds a shell alias:

```bash
alias oide='NVIM_APPNAME=oncilla nvim'
```

Both names and the alias are promptable — press Enter for the defaults.

```
nvim   ->  your existing config
oide   ->  the Oncilla IDE
```

This uses Neovim's built-in `NVIM_APPNAME` mechanism, which is the correct way to
run parallel configurations. Setting it redirects *all* of Neovim's directories at
once, so the two installs share nothing:

| | `nvim` | `oide` |
|---|---|---|
| config | `~/.config/nvim` | `~/.config/oncilla` |
| plugins/data | `~/.local/share/nvim` | `~/.local/share/oncilla` |
| state | `~/.local/state/nvim` | `~/.local/state/oncilla` |
| cache | `~/.cache/nvim` | `~/.cache/oncilla` |

Separate plugin trees mean separate lazy.nvim installs and separate Mason servers —
the two configs cannot corrupt each other, at the cost of some disk space.

**Use this when** you want to trial the Oncilla IDE without giving up your current
setup, or you need both for different work.

**To undo:** remove the alias line from `~/.zshrc` and `rm ~/.config/oncilla`
(it's only a symlink), plus `rm -rf ~/.local/share/oncilla ~/.local/state/oncilla
~/.cache/oncilla` to reclaim the plugin data.

### Option 3 — Quit

Aborts immediately. Nothing on disk changes.

---

## Manual step — the one thing that can't be scripted

Every terminal stores its font in its own preferences, so this one is a human step
whichever terminal you use:

| Terminal | Where |
|---|---|
| iTerm2 | Settings → Profiles → Text → Font |
| Terminal.app | Settings → Profiles → Text → Font |

Choose **`JetBrainsMono Nerd Font`**. The installer marks whichever terminal you ran
it from with a `>`.

### A note on Terminal.app

Terminal.app is 256-color only, but the config sets `termguicolors`. Gruvbox and the
dashboard's ANSI logo (generated with truecolor) will both look washed out — a
terminal limitation, not a config bug. Check with:

```bash
printf '\033[38;2;255;100;0mTRUECOLOR\033[0m\n'
```

Orange means truecolor works. For an accurate view of the IDE, use iTerm2
(`brew install --cask iterm2`).

Without it, the file-tree icons, the bufferline separators, and the dashboard glyphs
all render as empty boxes. The installer reminds you of this at the end.

---

## After installing

Open the editor (`nvim`, or `oide` in side-by-side mode) and let it work. On the
first launch it bootstraps lazy.nvim, installs all pinned plugins, compiles the
treesitter parsers, and has Mason download the language servers.

Then verify:

| Command | Checks |
|---|---|
| `:Lazy` | all plugins installed, none failed |
| `:Mason` | all 8 language servers present |
| `:checkhealth` | providers, treesitter parsers, terminal capabilities |
| `:LspInfo` | the right server attached to the current buffer |

The dashboard's bottom line is a quick health signal in itself — it shows the Neovim
version and how many plugins loaded, e.g.
`⚡ Neovim v0.12.5 · 29/31 plugins in 28.7ms`. The count is `loaded/total`; the two
unloaded ones are lazy-loaded by filetype and will differ from run to run.

---

## Versioning

The IDE version lives in `macOS IDE/nvim/lua/oncilla/version.lua` and is displayed
on the dashboard. It follows [Semantic Versioning](https://semver.org):

- **MAJOR** — a breaking change: keymaps, commands or workflows change or disappear
  and you have to relearn something.
- **MINOR** — a new capability, added compatibly.
- **PATCH** — a fix, with no new behaviour.

Bumping a part resets the parts to its right (`0.1.3` → minor → `0.2.0`). While
MAJOR is `0`, the config is still finding its shape and anything may change; `1.0.0`
is the promise that it won't without a MAJOR bump.

Releases are tagged in git, with a `v` prefix on the tag only:

```bash
# edit the numbers in lua/oncilla/version.lua, then:
git commit -am "Bump version to 0.2.0"
git tag -a v0.2.0 -m "Oncilla IDE v0.2.0"
git push && git push origin v0.2.0     # tags do NOT ride along with a branch push
```

Keep the `version.lua` edit in the same commit the tag points at, so the dashboard
can never disagree with the tag. Never move or reuse a published tag — fix forward
with a new patch version instead.

---

## Known gaps

- **`Linux IDE/`** has no installer and lags the macOS config (no dashboard).
- **Debugging is not wired up.** `nvim-dap-ui` is configured, but no DAP adapter is
  defined anywhere in the config, so there is nothing to attach to. The installer
  therefore provisions no debug adapters.
- **Mason repo transfer.** `lsp.lua` still references `williamboman/mason.nvim` and
  `williamboman/mason-lspconfig.nvim`; both moved to the `mason-org` organisation
  and currently work via GitHub redirects.
