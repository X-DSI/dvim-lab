# Oncilla IDE — Setup (Linux)

The Linux counterpart to [macOS IDE/SETUP.md](../macOS%20IDE/SETUP.md). The Neovim
config is **byte-identical** between the two platforms; only the installer differs.

- **Installer:** `bootstrap-linux.sh`, beside this file
- **Target:** Debian / Ubuntu (apt), x86_64 or arm64
- **Version:** see `nvim/lua/oncilla/version.lua`

---

## Quick start

```bash
git clone git@gitlab.com:oncilla-llc-group/vim-ide.git
cd vim-ide/"Linux IDE"
./bootstrap-linux.sh --dry-run     # read what it plans to do
./bootstrap-linux.sh               # then do it for real
```

Same flags as the macOS script: `--dry-run`, `--yes`, `--mode=replace|sidebyside`,
`--help`. Same guarantees: interactive, idempotent, never deletes anything.

**One difference worth knowing up front:** on macOS only a single step needed
`sudo`. Here apt needs root throughout, plus installing Neovim into `/opt`. Every
privileged command is printed before it runs.

---

## The `ovim` command

The IDE is called **OVIM** — that's the name on the dashboard, and `ovim` is how you
open it:

```bash
alias ovim='nvim'
```

The installer adds that to your shell rc file, idempotently. In the default
**replace** mode `~/.config/nvim` *is* the IDE, so `ovim` and `nvim` are simply two
names for the same editor, sharing one config and one plugin tree. In
**side-by-side** mode the alias carries the `NVIM_APPNAME` instead, so `ovim` opens
the IDE while `nvim` keeps running your existing config.

Being an alias, `ovim` works in interactive shells. If you ever want it available to
other programs too — `EDITOR=ovim`, `git config core.editor ovim`, desktop entries —
replace it with a two-line script on `PATH`:

```sh
# ~/.local/bin/ovim
#!/bin/sh
exec nvim "$@"
```

---

## Why the Linux installer is a separate script

These are not cosmetic differences — each one silently breaks the IDE if handled
the macOS way:

| | macOS | Linux |
|---|---|---|
| Package manager | Homebrew (user-owned, no sudo) | apt (root, sudo throughout) |
| Neovim source | `brew install neovim` | **official tarball** — apt's is far too old |
| Composer global bin | `~/.composer/vendor/bin` | **`~/.config/composer/vendor/bin`** |
| `fd` binary name | `fd` | **`fdfind`** — needs a shim |
| Shell rc | `~/.zshrc` | `~/.bashrc` (detected from `$SHELL`) |
| Nerd Font | `brew install --cask` | download + unzip + `fc-cache` |
| JDK | keg-only, needs a sudo symlink | `apt install openjdk-21-jdk`, no symlink |
| tree-sitter CLI | `brew install tree-sitter-cli` | npm (not packaged in apt) |
| Clipboard | built in | needs `xclip` or `wl-clipboard` |

### Neovim: do not use apt

This is the single most important thing on Linux. Ubuntu ships:

| Release | apt's Neovim | Usable? |
|---|---|---|
| 22.04 | 0.6.1 | **No** |
| 24.04 | 0.9.5 | **No** |

The config requires **≥ 0.11** — it uses `vim.uv` and `vim.lsp.config()`, neither of
which exists earlier. With apt's version you get a wall of errors that look like
config bugs but are purely a version problem. The installer therefore fetches the
official release tarball, installs it to `/opt/nvim`, and symlinks
`/usr/local/bin/nvim`. Any existing `/opt/nvim` is moved to a timestamped backup,
never deleted.

Check before anything else:

```bash
nvim --version | head -1
```

### Composer's global bin directory

On Linux, Composer follows the XDG spec, so global packages land in
`~/.config/composer/vendor/bin` — *not* the `~/.composer/vendor/bin` used on macOS.
Copying the macOS PATH line across is the most likely way to end up with `phpcs`
and `phpcbf` installed but unreachable, which shows up as PHP linting and
formatting silently doing nothing.

```bash
export PATH="$HOME/.config/composer/vendor/bin:$PATH"
```

### The tree-sitter CLI and glibc

npm's `tree-sitter-cli` package ships a **prebuilt binary linked against glibc
2.39** — the version on Ubuntu 24.04. On Ubuntu 22.04 (glibc 2.35) it installs
cleanly, lands on `PATH`, and then fails the moment anything executes it:

```
tree-sitter: /lib/aarch64-linux-gnu/libc.so.6: version `GLIBC_2.39' not found
```

nvim-treesitter then fails every parser build, and you end up with an editor where
treesitter looks installed and **nothing is highlighted**. `:checkhealth
nvim-treesitter` shows only the query-only sub-grammars (`ecma`, `html_tags`,
`jsx`) under "Installed languages", with none of the real parsers.

The installer therefore tests whether the binary actually **runs**, not merely
whether it exists. If it doesn't, it offers to remove the broken npm package and
build the CLI from source with `cargo`, which links against the local libc. That
needs the Rust toolchain (installed via rustup if absent) and takes a few minutes.

If you hit this after the fact, the manual fix is:

```bash
sudo npm uninstall -g tree-sitter-cli
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
. "$HOME/.cargo/env"
cargo install tree-sitter-cli
```

Then reopen Neovim — `treesitter.lua` calls `install()` on every startup, so the
parsers build on the next launch.

### `fd` is called `fdfind`

Debian already had a package named `fd`, so `fd-find` installs its binary as
`fdfind`. Telescope looks for `fd`. The installer creates a shim at
`~/.local/bin/fd` and makes sure that directory is on `PATH`.

---

## Dependency manifest

### apt packages

| Package | Needed by |
|---|---|
| `build-essential` | C toolchain — nvim-treesitter compiles parsers from source |
| `git` | lazy.nvim clones plugins |
| `curl` | Mason downloads; the Neovim and font tarballs |
| `unzip` | Mason unpacks servers; the font zip |
| `ripgrep` | Telescope `live_grep` |
| `fd-find` | Telescope `find_files` (installs as `fdfind`) |
| `fontconfig` | `fc-cache`, to register the Nerd Font |
| `php-cli` | runtime for Composer and phpcs/phpcbf |
| `php-mbstring`, `php-xml` | required by php_codesniffer and Composer |
| `composer` | installs phpcs/phpcbf — **needs PHP first** |
| `openjdk-21-jdk` | `jdtls`. Ubuntu 22.04's `default-jdk` is Java 11, which current jdtls will not run on |
| `xclip` *or* `wl-clipboard` | clipboard integration; chosen from `$XDG_SESSION_TYPE` |

### Not from apt

| Item | Source | Why not apt |
|---|---|---|
| **Neovim** | official release tarball → `/opt/nvim` | apt's is 0.6/0.9; config needs ≥ 0.11 |
| **Node.js** | NodeSource LTS repo | apt's is 12.x on 22.04; servers need ≥ 18 |
| **tree-sitter CLI** | npm, **falling back to `cargo`** — see below | not packaged; needed by nvim-treesitter's `main` branch |
| **Nerd Font** | nerd-fonts release zip → `~/.local/share/fonts` | no cask equivalent |

An existing new-enough Node from `nvm`, `fnm`, or `volta` is detected and left
alone. The installer also checks whether npm's prefix is writable and only uses
`sudo` for global installs when it isn't — so an nvm-managed Node is never
polluted with root-owned files.

### npm globals

`@fsouza/prettierd`, `eslint_d` — resolved from `PATH` by conform.nvim and
nvim-lint, not managed by Mason.

### Composer globals

`squizlabs/php_codesniffer`, providing both `phpcs` (linter) and `phpcbf`
(formatter).

### Language servers

Installed by Mason inside Neovim, same 8 as macOS: `jdtls`, `ts_ls`,
`intelephense`, `lua_ls`, `html`, `cssls`, `jsonls`, `emmet_language_server`. The
installer launches Neovim **last** so Mason resolves them against runtimes that
already exist.

---

## Handling an existing Neovim config

Identical to macOS — three choices, explained in full in
[macOS IDE/SETUP.md](../macOS%20IDE/SETUP.md#handling-an-existing-neovim-or-spacevim-config):

1. **Back up and replace** — existing config and data moved to `.bak.TIMESTAMP`.
2. **Side-by-side** — installs to `~/.config/oncilla` with an `ovim` alias, leaving
   `~/.config/nvim` untouched.
3. **Quit.**

---

## Manual step

Set your terminal's font to **`JetBrainsMono Nerd Font`**:

| Terminal | Where |
|---|---|
| GNOME Terminal | Menu → Preferences → *your profile* → Text → tick "Custom font" |
| Konsole | Settings → Edit Current Profile → Appearance |
| Alacritty | `font.normal.family` in `alacritty.toml` |

Without it the file-tree icons, bufferline separators and dashboard glyphs render
as empty boxes.

---

## After installing

```bash
ovim        # or `nvim` — both open this config in replace mode
```

Verify with `:Lazy` (31 plugins), `:Mason` (8 servers), and `:checkhealth`.

### Linux-specific things to check

**Treesitter queries.** In `:checkhealth nvim-treesitter`, confirm:

```
Install directory for parsers and queries
- ✅ OK is in runtimepath.
```

and that the installed languages show `✓` in the H/L/F/I/J columns, not dots. If
that directory is missing from `runtimepath`, parsers load but every query —
highlights, folds, indents — is silently absent, so treesitter appears installed
while nothing is highlighted. `init.lua` appends the path defensively, which
should prevent this, but it is the one place where Linux and macOS have been
observed to behave differently.

**Format-on-save.** The npm/Composer PATH chain is the piece most likely to be
quietly broken, because those tools resolve from `PATH` rather than Mason. In a
**new** terminal, so the rc changes are live:

```bash
printf 'const x   =    1\n' > /tmp/t.js  && nvim /tmp/t.js    # :w should reformat
printf '<?php\n$x=1;\n'     > /tmp/t.php && nvim /tmp/t.php   # :w should reformat
```

If JS reformats and PHP doesn't, it's the Composer PATH entry — check it points at
`~/.config/composer/vendor/bin`.

A `phpcbf unavailable: Command 'phpcbf' not found` in `:checkhealth conform`
almost always means the shell predates the rc edit rather than a failed install.
Open a **new** terminal, or `source ~/.bashrc`, and check again. The installer
exports the new entries into its own environment before the first launch so the
headless run isn't caught by this, and prints where each tool resolves at the end
of the PATH step.

`:checkhealth conform` should report `phpcbf ready (php)` and `prettierd ready`
for the ten JS/TS/CSS/JSON/Markdown filetypes.

### Noise you can ignore

`:checkhealth` on Linux reports a lot that doesn't matter here:

- **snacks `image` / `lazygit` / `notifier` / `picker` errors** — those modules are
  deliberately disabled in `dashboard.lua`. The kitty-graphics error is the
  expected fallback to ANSI logo art in GNOME Terminal.
- **`luarocks` / hererocks not installed** — preceded by "no plugins require
  luarocks".
- **`fd 8.3.1 is too old`** — applies only to `Snacks.picker`, which is off.
  Telescope reports the same `fd` as fine.
- **which-key `<g>` overlaps** and the toggleterm `vim.validate` deprecation —
  cosmetic, and upstream.

---

## Versioning

Shared with macOS — see [macOS IDE/SETUP.md](../macOS%20IDE/SETUP.md#versioning).
