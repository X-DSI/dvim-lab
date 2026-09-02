# Keybindings

[← Wiki home](Home.md)

Every shortcut in OVIM: the ones we added, the ones plugins provide, and the Neovim
fundamentals underneath. Everything here was read out of the live config and the
installed plugins, not from memory.

`<leader>` is the **spacebar**. Press it and pause — which-key shows you what's
available.

---

## Part 1 — What we added

These are defined in `init.lua` and in the plugin configs. This is the complete list;
there is nothing else custom.

### Files and search

| Key | Does |
|---|---|
| `<leader>ff` | Find files (Telescope) |
| `<leader>fg` | Live grep across the project (Telescope + ripgrep) |
| `<leader>fb` | Switch between open buffers |
| `<leader>e` | Toggle the file tree |

### Buffers

| Key | Does |
|---|---|
| `gl` | Next buffer |
| `gh` | Previous buffer |
| `<C-x>` | Close the current buffer |

### Windows

| Key | Does |
|---|---|
| `<C-h>` | Go to the window on the left |
| `<C-j>` | Go to the window below |
| `<C-k>` | Go to the window above |
| `<C-l>` | Go to the window on the right |

These work **from inside the terminal too** — the terminal-mode versions leave insert
mode first, so you don't need `<C-\><C-n>` before moving.

### Terminal

| Key | Does |
|---|---|
| `<leader>tt` | Toggle the terminal |
| `<C-\>` | Toggle the terminal (toggleterm's own mapping) |
| `<C-\><C-n>` | Leave terminal insert mode (Neovim built-in) |

### Dashboard

Only on the start screen:

| Key | Does |
|---|---|
| `f` | Find files |
| `g` | Live grep |
| `r` | Recent files |
| `b` | Buffers |
| `e` | File explorer |
| `q` | Quit |

---

## Part 2 — From Neovim itself

Neovim 0.11+ ships these. They are not ours, but they're the ones you'll use most.

### Language server

Available whenever a server is attached to the buffer.

| Key | Does |
|---|---|
| `K` | Hover documentation for the symbol under the cursor |
| `grn` | Rename the symbol, everywhere |
| `gra` | Code action (quick fixes, imports, refactors) |
| `grr` | List references |
| `gri` | Go to implementation |
| `grt` | Go to type definition |
| `grx` | Run code lens |
| `gO` | Document symbols — an outline of this file |
| `<C-s>` *(insert mode)* | Signature help while typing arguments |

Go-to-definition is `<C-]>`, and `<C-o>` jumps back where you came from.

### Diagnostics

| Key | Does |
|---|---|
| `]d` | Next diagnostic |
| `[d` | Previous diagnostic |
| `]D` | Last diagnostic in the buffer |
| `[D` | First diagnostic in the buffer |
| `<C-w>d` | Show the full diagnostic under the cursor in a float |

Useful when a message is truncated: `<C-w>d` gives you the whole thing.

### Other built-ins worth knowing

| Key | Does |
|---|---|
| `gx` | Open the file path or URL under the cursor in your system handler |
| `gq` | Reformat the selected lines to `textwidth` |
| `g;` | Jump to your previous edit position |
| `gv` | Reselect the last visual selection |

---

## Part 3 — From plugins

### Comments (Comment.nvim)

| Key | Does |
|---|---|
| `gcc` | Toggle comment on the current line |
| `gc{motion}` | Toggle comment over a motion — `gcap` for a paragraph, `gc3j` for 3 lines down |
| `gc` *(visual)* | Toggle comment on the selection |
| `gco` | Insert a comment on the line below and start typing |
| `gcO` | Insert a comment on the line above |
| `gcA` | Append a comment at the end of the line |
| `gbc` | Toggle a block comment on the current line |
| `gb{motion}` | Toggle a block comment over a motion |

### Completion (nvim-cmp)

| Key | Does |
|---|---|
| `<C-Space>` | Open the completion menu |
| `<CR>` | Confirm the selected entry |
| `<C-n>` / `<C-p>` | Next / previous entry |

Sources, in priority order: language server → snippets → current buffer → file paths.

### Telescope

Inside a picker, in insert mode:

| Key | Does |
|---|---|
| `<C-n>` / `<C-p>` | Next / previous result |
| `<CR>` | Open the selection |
| `<C-x>` | Open in a horizontal split |
| `<C-v>` | Open in a vertical split |
| `<C-t>` | Open in a new tab |
| `<C-u>` / `<C-d>` | Scroll the preview up / down |
| `<Tab>` / `<S-Tab>` | Select this result and move down / up (multi-select) |
| `<C-q>` | Send all results to the quickfix list |
| `<C-r><C-w>` | Insert the word under the cursor into the prompt |
| `<C-c>` | Close |
| `<C-/>` | **Show every mapping for this picker** |
| `<Esc>` | Switch to normal mode inside the picker |

`<C-/>` is the one to remember — it's the authoritative list, live.

Note `<C-k>` scrolls the preview here rather than moving between windows, and `<C-l>`
completes a tag. Prompt mappings win inside the picker.

### File tree (nvim-tree)

With the cursor in the tree:

| Key | Does |
|---|---|
| `<CR>` / `o` | Open file, or expand/collapse a directory |
| `<Tab>` | Preview the file without leaving the tree |
| `<C-v>` / `<C-x>` / `<C-t>` | Open in vertical split / horizontal split / new tab |
| `a` | Create a file or directory — a trailing `/` makes a directory |
| `r` | Rename |
| `d` | Delete |
| `D` | Move to trash |
| `x` / `c` / `p` | Cut / copy / paste |
| `y` / `Y` / `gy` | Copy the name / relative path / absolute path |
| `R` | Refresh the tree |
| `H` | Toggle hidden (dot) files |
| `I` | Toggle git-ignored files |
| `E` / `W` | Expand all / collapse all |
| `f` / `F` | Start live filter / clear it |
| `S` | Search |
| `]c` / `[c` | Next / previous git-changed file |
| `]e` / `[e` | Next / previous diagnostic in the tree |
| `P` | Jump to the parent directory |
| `<BS>` | Close the current directory |
| `q` | Close the tree |
| `g?` | **Show all tree mappings** |

`g?` is the live list, same idea as Telescope's `<C-/>`.

### Git (gitsigns)

**No keymaps are bound.** Signs appear in the gutter, but everything else is a
command:

| Command | Does |
|---|---|
| `:Gitsigns next_hunk` / `prev_hunk` | Move between changes |
| `:Gitsigns preview_hunk` | Show the diff for this hunk |
| `:Gitsigns stage_hunk` | Stage it |
| `:Gitsigns reset_hunk` | Discard it |
| `:Gitsigns blame_line` | Who last touched this line |

Worth binding if you use git from inside the editor — a candidate for a future
version.

### Debugging (nvim-dap)

Installed and configured, but **no debug adapter is defined for any language**, so
there is nothing to attach to yet. The UI opens; it has no session. Tracked as a
known gap.

---

## Part 4 — Neovim fundamentals

If you're new to modal editing, this is the part that makes the rest make sense.

### Modes

| Mode | Enter with | For |
|---|---|---|
| **Normal** | `<Esc>` | Moving and running commands. You start here and return here |
| **Insert** | `i` `a` `o` `I` `A` `O` | Typing text |
| **Visual** | `v` `V` `<C-v>` | Selecting — by character, by line, by block |
| **Command** | `:` | `:w`, `:q`, and every other command |
| **Terminal** | `i` in a terminal buffer | Typing into a shell |

### Moving

| Key | Moves |
|---|---|
| `h` `j` `k` `l` | Left, down, up, right |
| `w` / `b` | Forward / back one word |
| `e` | End of the word |
| `0` / `^` / `$` | Start of line / first non-blank / end of line |
| `gg` / `G` | Top / bottom of the file |
| `{` / `}` | Previous / next paragraph |
| `%` | Jump to the matching bracket |
| `<C-u>` / `<C-d>` | Half a page up / down |
| `f{char}` / `t{char}` | Jump to / just before the next `{char}` on this line |
| `*` / `#` | Next / previous occurrence of the word under the cursor |

### Editing

Operators combine with motions. That composition **is** Vim: `d` + `w` deletes a
word, `c` + `$` changes to end of line, `y` + `y` yanks a line.

| Key | Does |
|---|---|
| `d{motion}` | Delete |
| `c{motion}` | Change — delete, then enter insert mode |
| `y{motion}` | Yank (copy) |
| `p` / `P` | Paste after / before the cursor |
| `dd` / `yy` / `cc` | Whole-line versions |
| `x` | Delete the character under the cursor |
| `u` / `<C-r>` | Undo / redo |
| `.` | **Repeat the last change.** The most valuable key on the keyboard |
| `>>` / `<<` | Indent / dedent the line |

### Text objects

Used with operators. `i` means "inner", `a` means "around" (includes the delimiters).

| Object | Is |
|---|---|
| `iw` / `aw` | Word |
| `i"` / `a"` | Inside / including quotes |
| `i(` / `a(` | Inside / including parentheses |
| `i{` / `a{` | Inside / including braces |
| `it` / `at` | Inside / including an HTML/XML tag |
| `ip` / `ap` | Paragraph |

`ci"` changes what's inside the quotes. `dat` deletes a whole tag. `yi{` yanks a
block's body. Treesitter is what makes these reliable in JSX and PHP.

### Search and replace

| Key | Does |
|---|---|
| `/text` | Search forward |
| `?text` | Search backward |
| `n` / `N` | Next / previous match |
| `:%s/old/new/g` | Replace in the whole file |
| `:%s/old/new/gc` | Same, confirming each one |
| `:noh` | Clear the search highlight |

### Files, buffers, windows

| Key / command | Does |
|---|---|
| `:w` / `:q` / `:wq` | Write / quit / write and quit |
| `:q!` | Quit, discarding changes |
| `:e {file}` | Open a file |
| `:sp` / `:vs` | Split horizontally / vertically |
| `<C-w>q` | Close the current window |
| `<C-w>=` | Equalise window sizes |
| `<C-w>o` | Close every window but this one |

For moving between windows, use our `<C-h/j/k/l>` — fewer keys than `<C-w>h`.

---

## Learning it

Two things beat any cheatsheet:

- **`:Tutor`** — Neovim's built-in 30-minute interactive tutorial. If you're new,
  this is the highest-value half hour available.
- **`:help {topic}`** — always matches your version, unlike anything on the web.

A printable one-page cheatsheet for Oncilla developers is planned.

---

[← Wiki home](Home.md) · [Architecture →](Architecture.md) · [Installation →](Installation.md)
