# jerboa-ts-mode

Tree-sitter grammar and Emacs major mode for [Jerboa Scheme](https://github.com/ober/jerboa), a Chez Scheme dialect with Gerbil-inspired syntax extensions.

## What's Included

| File | Purpose |
|------|---------|
| `grammar.js` | Tree-sitter grammar definition |
| `src/scanner.c` | External scanner for heredocs (`#<<DELIM`) and nested block comments (`#\|...\|#`) |
| `src/parser.c` | Generated parser (checked in for compilation) |
| `jerboa-ts-mode.el` | Emacs 29+ tree-sitter major mode |
| `queries/highlights.scm` | Highlight queries (Emacs, Neovim, Helix, etc.) |
| `test/corpus/basics.txt` | Parser test corpus |

## Language Features Supported

- **Definition forms**: `def`, `def*`, `define`, `defstruct`, `defclass`, `defrecord`, `defmethod`, `defgeneric`, `defrule`, `defsyntax`, `define-enum`
- **Reader syntax**: `[...]` bracket lists, `{...}` method dispatch, `name:` keywords, `#:name` keywords
- **Heredoc strings**: `#<<DELIM\n...\nDELIM` (via external C scanner)
- **Block comments**: `#|...|#` with nesting support (via external C scanner)
- **Directives**: `#!/usr/bin/env scheme-script`, `#!chezscheme`, `#!r6rs`
- **Quote variants**: `'`, `` ` ``, `,`, `,@`, `#'`, `` #` ``, `#,`, `#,@`
- **Datum comments**: `#;`
- **All Chez Scheme**: numbers (radix, exact/inexact, rationals), characters (`#\space`), booleans, vectors, bytevectors

## Installation in GNU Emacs (29+)

### Prerequisites

Your Emacs must be compiled with tree-sitter support. Verify:

```elisp
(treesit-available-p)  ;; Must return t
```

If it returns `nil`, you need an Emacs build with `--with-tree-sitter`. On most package managers this is the default for Emacs 29+.

You also need a C compiler (gcc or clang) available -- Emacs compiles the grammar from source.

### Step 1: Install the tree-sitter grammar

Add the grammar source to Emacs and compile it:

```elisp
;; In your init.el, early-init.el, or evaluate interactively:
(add-to-list 'treesit-language-source-alist
             '(jerboa "https://github.com/ober/jerboa-ts-mode" "master" "src"))

;; Then install (only needed once, or after grammar updates):
(treesit-install-language-grammar 'jerboa)
```

This downloads the repo, compiles `src/parser.c` and `src/scanner.c` into a shared library, and installs it into `~/.emacs.d/tree-sitter/` (or wherever `treesit-extra-load-path` points).

To verify the grammar is installed:

```elisp
(treesit-language-available-p 'jerboa)  ;; Should return t
```

### Step 2: Install the Emacs mode

#### Option A: Load from local clone (recommended for development)

```bash
cd ~/mine
git clone git@github.com:ober/jerboa-ts-mode.git
```

Then in your Emacs init:

```elisp
(add-to-list 'load-path "~/mine/jerboa-ts-mode")
(require 'jerboa-ts-mode)
```

#### Option B: use-package with local path

```elisp
(use-package jerboa-ts-mode
  :load-path "~/mine/jerboa-ts-mode"
  :mode ("\\.ss\\'" "\\.sls\\'"))
```

#### Option C: use-package with vc (Emacs 30+)

```elisp
(use-package jerboa-ts-mode
  :vc (:url "https://github.com/ober/jerboa-ts-mode" :branch "master")
  :mode ("\\.ss\\'" "\\.sls\\'"))
```

#### Option D: straight.el

```elisp
(straight-use-package
 '(jerboa-ts-mode :type git :host github :repo "ober/jerboa-ts-mode"))
```

### Step 3: Verify

Open any `.ss` file. The mode line should show `Jerboa`. You should see syntax highlighting for all Jerboa forms.

If `.ss` files open in a different mode (e.g., `scheme-mode` or `gerbil-mode`), ensure `jerboa-ts-mode` is loaded _after_ those modes, or explicitly set the association:

```elisp
(add-to-list 'auto-mode-alist '("\\.ss\\'" . jerboa-ts-mode))
(add-to-list 'auto-mode-alist '("\\.sls\\'" . jerboa-ts-mode))
```

### Customization

```elisp
;; Change the REPL command (default: "scheme")
(setq jerboa-ts-program-name "scheme")

;; Change REPL arguments (default: ("--libdirs" "lib"))
(setq jerboa-ts-program-args '("--libdirs" "lib"))

;; Adjust font-lock level (1 = minimal, 4 = maximum)
;; Level 1: comments, strings
;; Level 2: + keywords, definitions
;; Level 3: + builtins, constants, properties
;; Level 4: + types, brackets, function calls, operators
(setq treesit-font-lock-level 4)
```

### Updating the grammar

When the grammar is updated upstream:

```bash
cd ~/mine/jerboa-ts-mode && git pull
```

Then in Emacs:

```elisp
(treesit-install-language-grammar 'jerboa)  ;; Recompile
```

Restart Emacs or re-evaluate `(require 'jerboa-ts-mode)`.

## Integration with jerboa-emacs

[jerboa-emacs](https://github.com/ober/jerboa-emacs) is a Chez Scheme text editor that can consume the tree-sitter grammar directly for syntax highlighting of `.ss` and `.sls` buffers.

### Using the compiled grammar shared library

After installing the grammar via GNU Emacs (Step 1 above), a compiled shared library exists at:

```
~/.emacs.d/tree-sitter/libtree-sitter-jerboa.so    # Linux
~/.emacs.d/tree-sitter/libtree-sitter-jerboa.dylib  # macOS
```

jerboa-emacs can load this library via its FFI to get access to the parser. The key C entry point is:

```c
const TSLanguage *tree_sitter_jerboa(void);
```

### Using the highlight queries

The file `queries/highlights.scm` contains highlight queries in the standard tree-sitter query format. jerboa-emacs can read this file at runtime:

```scheme
;; In jerboa-emacs Scheme code:
(import (std text file))

(def highlights-query
  (read-file-string "~/mine/jerboa-ts-mode/queries/highlights.scm"))
```

### Building the shared library directly (without GNU Emacs)

If you need the `.so`/`.dylib` without going through Emacs:

```bash
cd ~/mine/jerboa-ts-mode

# Generate (if grammar.js changed)
npx tree-sitter generate

# Compile the shared library
cc -shared -fPIC -O2 \
   -I src \
   src/parser.c src/scanner.c \
   -o libtree-sitter-jerboa.so
```

Then point jerboa-emacs at the resulting `libtree-sitter-jerboa.so`:

```scheme
;; Load via Chez FFI
(def ts-jerboa
  (load-shared-object "~/mine/jerboa-ts-mode/libtree-sitter-jerboa.so"))
```

### Adding to jerboa-emacs LIBDIRS

If jerboa-emacs needs the grammar at build time, add to the Makefile:

```makefile
TS_JERBOA = $(HOME)/mine/jerboa-ts-mode
```

### Query format reference

The highlight queries use tree-sitter's S-expression pattern syntax. Each capture maps a node type to a highlight group:

| Capture | Meaning | Example nodes |
|---------|---------|---------------|
| `@keyword` | Language keywords | `def`, `match`, `try`, `for/collect` |
| `@function` | Function definitions | name in `(def (name ...) ...)` |
| `@function.method` | Method definitions | name in `(defmethod (name ...) ...)` |
| `@function.macro` | Macro definitions | name in `(defrule (name ...) ...)` |
| `@function.builtin` | Prelude builtins | `cons`, `map`, `hash-put!` |
| `@function.call` | Function calls | head symbol of any list |
| `@type` | Type definitions | name in `defstruct`, `defclass`, `define-enum` |
| `@keyword.import` | Import/export | `import`, `export` |
| `@keyword.conditional` | Conditionals | `if`, `when`, `unless`, `cond` |
| `@keyword.repeat` | Iteration | `for`, `for/collect`, `for/fold` |
| `@keyword.exception` | Exception handling | `try` |
| `@keyword.directive` | Directives | `#!chezscheme`, shebang |
| `@string` | Strings and heredocs | `"hello"`, `#<<EOF...EOF` |
| `@number` | Numeric literals | `42`, `3.14`, `#xff` |
| `@boolean` | Boolean constants | `#t`, `#f` |
| `@character` | Character literals | `#\a`, `#\space` |
| `@comment` | Comments | `; ...`, `#\|...\|#`, `#;` |
| `@property` | Keywords | `name:`, `#:name` |
| `@punctuation.bracket` | Brackets | `()`, `[]`, `{}` |
| `@operator` | Special symbols | `=>`, `...`, `_`, `<>` |
| `@module` | Module names | name in `(module name ...)` |

## Using with other editors

### Neovim

Copy the queries directory into your Neovim tree-sitter config:

```bash
mkdir -p ~/.config/nvim/queries/jerboa
cp ~/mine/jerboa-ts-mode/queries/highlights.scm ~/.config/nvim/queries/jerboa/
```

Then register the parser in your Neovim config (lua):

```lua
local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
parser_config.jerboa = {
  install_info = {
    url = "~/mine/jerboa-ts-mode",
    files = { "src/parser.c", "src/scanner.c" },
  },
  filetype = "jerboa",
}

vim.filetype.add({
  extension = { ss = "jerboa", sls = "jerboa" },
})
```

### Helix

```bash
mkdir -p ~/.config/helix/runtime/queries/jerboa
cp ~/mine/jerboa-ts-mode/queries/highlights.scm ~/.config/helix/runtime/queries/jerboa/
```

Add to `~/.config/helix/languages.toml`:

```toml
[[language]]
name = "jerboa"
scope = "source.jerboa"
file-types = ["ss", "sls"]
comment-token = ";;"
indent = { tab-width = 2, unit = "  " }

[language.auto-pairs]
'(' = ')'
'[' = ']'
'{' = '}'
'"' = '"'

[[grammar]]
name = "jerboa"
source = { path = "/home/you/mine/jerboa-ts-mode" }
```

## Development

### Modifying the grammar

```bash
cd ~/mine/jerboa-ts-mode

# Edit grammar.js and/or src/scanner.c

# Regenerate the parser
npx tree-sitter generate

# Run the test corpus
npx tree-sitter test

# Test against a real file
npx tree-sitter parse ~/mine/jerboa/jerbuild.ss

# Recompile for Emacs
# (in Emacs) M-x eval-expression RET (treesit-install-language-grammar 'jerboa) RET
```

### Adding test cases

Add tests to `test/corpus/basics.txt` in tree-sitter's test format:

```
================
Test name
================

(source code here)

---

(expected S-expression tree here)
```

Run `npx tree-sitter test` to validate.

## Coexisting with jerboa-mode (regex-based)

The Jerboa repo also ships a regex-based `jerboa-mode` at `~/mine/jerboa/etc/jerboa-mode.el` for Emacs versions < 29 or systems without tree-sitter. Only load one:

```elisp
;; Prefer tree-sitter when available, fall back to regex
(if (and (fboundp 'treesit-available-p)
         (treesit-available-p)
         (treesit-language-available-p 'jerboa))
    (progn
      (add-to-list 'load-path "~/mine/jerboa-ts-mode")
      (require 'jerboa-ts-mode))
  (add-to-list 'load-path "~/mine/jerboa/etc")
  (require 'jerboa-mode))
```

## License

MIT
