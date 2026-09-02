# Installation — the setup process

[← Wiki home](Home.md)

How a bare machine becomes a working OVIM install. Platform-specific dependency
manifests and troubleshooting live beside their installers:
[macOS IDE/SETUP.md](../macOS%20IDE/SETUP.md) ·
[Linux IDE/SETUP.md](../Linux%20IDE/SETUP.md).

---

## The short version

```bash
git clone git@gitlab.com:oncilla-llc-group/vim-ide.git

cd vim-ide/"macOS IDE" && ./bootstrap-macos.sh     # macOS
cd vim-ide/"Linux IDE" && ./bootstrap-linux.sh     # Ubuntu / Debian
```

Then set your terminal font to **JetBrainsMono Nerd Font** and run `ovim`.

Run it with `--dry-run` first if you want to read the plan before anything happens.

---

## What the installer guarantees

**Interactive.** Every dependency is its own step. It checks first and prints the
version it found, asks before installing anything, shows the command output, and
pauses. Press `q` at any pause to stop cleanly with a summary of what happened.

**Idempotent.** Re-run it as often as you like. It detects existing installs, never
duplicates a `PATH` export or an alias or a symlink, and won't re-back-up a config it
already replaced.

**Non-destructive.** It never deletes. Existing configs are *moved* to timestamped
`.bak.YYYYMMDD-HHMMSS` directories. The only thing it removes is a symlink — and only
the link, never what it points at.

**It stops on errors.** A failed step asks whether to continue or abort rather than
barrelling on and leaving you to guess which of the next twenty steps was the real
problem.

### Flags

| Flag | Effect |
|---|---|
| `--dry-run` / `-n` | Print every command it *would* run; execute nothing |
| `--yes` / `-y` | Auto-answer yes, skip the pauses |
| `--mode=replace` | Pre-answer the existing-config question with option 1 |
| `--mode=sidebyside` | Pre-answer it with option 2 |
| `--help` / `-h` | Usage |

---

## The steps

Ordering is not arbitrary — each step depends on the ones before it.

| # | Step | Why here |
|---|---|---|
| 1 | Compiler toolchain | Treesitter compiles parsers from C source |
| 2 | Package manager | Homebrew on macOS; apt is already present on Ubuntu |
| 3 | System runtimes | Neovim, git, ripgrep, fd, node, php, composer, tree-sitter CLI |
| 4 | Java | jdtls is a JVM program and won't start without a JDK |
| 5 | Nerd Font | Icons in the file tree, bufferline and dashboard |
| 6 | npm globals | `prettierd`, `eslint_d` |
| 7 | Composer globals + PATH | `phpcs`, `phpcbf` — PHP must exist first, Composer is a PHP program |
| 8 | Existing-config handling | Before anything config-related is written |
| 9 | Symlink + `ovim` alias | Put the config in place |
| 10 | First launch | **Last**, so Mason resolves servers against runtimes that now exist |

That last point is the reason the whole ordering exists. Mason installs `jdtls`
against Java and five servers against Node. Launch the editor before those runtimes
are installed and you get a pile of failures that look like config bugs.

---

## The existing-config question

If you already have a Neovim setup, the installer stops and asks. It can tell the
difference between an empty slot, a real directory (and often *which* distribution —
SpaceVim, LazyVim, kickstart), and a symlink, including one already pointing at this
repo. A symlink is unlinked rather than moved, because moving a link preserves
nothing.

### Option 1 — Back up and replace

Moves your config to `~/.config/nvim.bak.<timestamp>` and symlinks this repo in its
place. Asks *separately* about the plugin/runtime data directories, since stale
lazy.nvim and Mason state from a previous config can confuse the first launch.
SpaceVim's own directories are a third, separate question — they don't conflict, so
the default is to leave them.

Both `ovim` and `nvim` then open OVIM.

**Use it when** you're committing to OVIM as your Neovim.

**To undo:**

```bash
rm ~/.config/nvim
mv ~/.config/nvim.bak.YYYYMMDD-HHMMSS ~/.config/nvim
```

### Option 2 — Side-by-side

Leaves `~/.config/nvim` **completely untouched**. Installs OVIM at
`~/.config/oncilla` and adds an alias:

```bash
alias ovim='NVIM_APPNAME=oncilla nvim'
```

```
nvim   ->  your existing config
ovim   ->  OVIM
```

`NVIM_APPNAME` is Neovim's own mechanism for parallel configurations. Setting it
redirects config, data, state and cache together, so the two installs share nothing
— separate plugin trees, separate Mason servers. They cannot corrupt each other, at
the cost of some disk space.

**Use it when** you want to try OVIM without giving up your current setup.

**To undo:** remove the alias line from your shell rc, then
`rm ~/.config/oncilla` (it's only a symlink) and
`rm -rf ~/.local/{share,state}/oncilla ~/.cache/oncilla`.

### Option 3 — Quit

Aborts. Nothing on disk changes.

---

## The manual step

Terminals store their font in their own preferences, so this one is yours to do:

| Terminal | Where |
|---|---|
| iTerm2 | Settings → Profiles → Text → Font |
| Terminal.app | Settings → Profiles → Text → Font |
| GNOME Terminal | Preferences → *your profile* → Text → Custom font |
| Konsole | Settings → Edit Current Profile → Appearance |
| Alacritty | `font.normal.family` in `alacritty.toml` |

Choose **JetBrainsMono Nerd Font**. Without it, file-tree icons, bufferline
separators and dashboard glyphs render as empty boxes or hex codes.

**Terminal.app users:** it is 256-colour only, while this config enables
`termguicolors`. Gruvbox and the dashboard logo will look washed out. That's the
terminal, not the config. Check with:

```bash
printf '\033[38;2;255;100;0mTRUECOLOR\033[0m\n'
```

Orange means truecolor works. If it doesn't, use iTerm2.

---

## Verifying the install

Open the editor and run these. In rough order of what's most likely to be wrong:

| Command | Look for |
|---|---|
| `:checkhealth nvim-treesitter` | `is in runtimepath`, and `✓` in the H/L/F/I/J columns — not dots |
| `:checkhealth conform` | `prettierd ready`, `phpcbf ready (php)` |
| `:Lazy` | 31 plugins, none failed |
| `:Mason` | 8 servers installed |
| `:LspInfo` | open a `.php` or `.java` file first; confirm a server attached |

And one end-to-end check that exercises the whole `PATH` chain, in a **new** terminal
so your shell rc changes are live:

```bash
printf 'const x   =    1\n' > /tmp/t.js  && ovim /tmp/t.js    # :w should reformat
printf '<?php\n$x=1;\n'     > /tmp/t.php && ovim /tmp/t.php   # :w should reformat
```

If JavaScript reformats and PHP doesn't, it's the Composer `PATH` entry.

---

## When something's wrong

**Nothing is highlighted, but treesitter looks installed.** The parsers built but
their queries aren't being found. Check `:checkhealth nvim-treesitter` for
`is in runtimepath`.

**Format-on-save does nothing.** Almost always `PATH`. `:checkhealth conform` names
the missing tool. Remember Composer's global bin directory differs by platform:
`~/.composer/vendor/bin` on macOS, `~/.config/composer/vendor/bin` on Linux.

**Icons are boxes.** The terminal font isn't a Nerd Font. See above.

**Errors everywhere on startup.** Check `nvim --version` — this config needs **0.11+**
for `vim.uv` and `vim.lsp.config()`. Ubuntu's apt ships 0.6 or 0.9; the Linux
installer deliberately uses the official tarball instead.

**Something else.** The plugin and runtime directories are disposable. Moving them
aside forces a clean rebuild and costs only time:

```bash
mv ~/.local/share/nvim ~/.local/share/nvim.bak
mv ~/.local/state/nvim ~/.local/state/nvim.bak
ovim   # reinstalls everything
```

---

[← Wiki home](Home.md) · [Architecture →](Architecture.md) · [Keybindings →](Keybindings.md)
