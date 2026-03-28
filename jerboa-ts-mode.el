;;; jerboa-ts-mode.el --- Tree-sitter mode for Jerboa Scheme -*- lexical-binding: t; -*-
;;
;; Author: Jerboa Contributors
;; Version: 1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: jerboa scheme lisp languages tree-sitter
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;;
;; Tree-sitter powered major mode for editing Jerboa Scheme code.
;; Requires Emacs 29+ with tree-sitter support and the tree-sitter-jerboa
;; grammar installed.
;;
;; To install the grammar:
;;   (add-to-list 'treesit-language-source-alist
;;                '(jerboa "https://github.com/ober/jerboa-ts-mode"))
;;   (treesit-install-language-grammar 'jerboa)
;;
;; To use this mode:
;;   (add-to-list 'load-path "/path/to/jerboa-ts-mode")
;;   (require 'jerboa-ts-mode)

;;; Code:

(require 'treesit)
(require 'scheme)

(declare-function treesit-parser-create "treesit.c")
(declare-function treesit-node-type "treesit.c")

(defgroup jerboa-ts-mode nil
  "Editing Jerboa Scheme code with tree-sitter."
  :prefix "jerboa-ts-"
  :group 'scheme)

(defcustom jerboa-ts-program-name "scheme"
  "Command to run the Jerboa Scheme REPL."
  :type 'string
  :group 'jerboa-ts-mode)

(defcustom jerboa-ts-program-args '("--libdirs" "lib")
  "Arguments passed to the Jerboa Scheme REPL."
  :type '(repeat string)
  :group 'jerboa-ts-mode)

;; ---------------------------------------------------------------------------
;; Font-lock rules
;; ---------------------------------------------------------------------------

(defvar jerboa-ts-mode--font-lock-settings
  (treesit-font-lock-rules

   ;; Level 1: comments and strings
   :language 'jerboa
   :feature 'comment
   '((comment) @font-lock-comment-face
     (block_comment) @font-lock-comment-face
     (datum_comment) @font-lock-comment-face
     (directive) @font-lock-preprocessor-face)

   :language 'jerboa
   :feature 'string
   '((string) @font-lock-string-face
     (heredoc) @font-lock-string-face
     (character) @font-lock-string-face)

   ;; Level 2: keywords
   :language 'jerboa
   :feature 'keyword
   '((definition keyword: (def_keyword) @font-lock-keyword-face)
     (type_definition keyword: (type_keyword) @font-lock-keyword-face)
     (method_definition keyword: (method_keyword) @font-lock-keyword-face)
     (macro_definition keyword: (macro_keyword) @font-lock-keyword-face)
     (enum_definition keyword: (enum_keyword) @font-lock-keyword-face)
     (import_form keyword: (import_keyword) @font-lock-keyword-face)
     (module_form keyword: (module_keyword) @font-lock-keyword-face)
     (lambda_form keyword: (lambda_keyword) @font-lock-keyword-face)
     (let_form keyword: (let_keyword) @font-lock-keyword-face)
     (if_form keyword: (conditional_keyword) @font-lock-keyword-face)
     (cond_form keyword: (cond_keyword) @font-lock-keyword-face)
     (match_form keyword: (match_keyword) @font-lock-keyword-face)
     (for_form keyword: (for_keyword) @font-lock-keyword-face)
     (try_form keyword: (try_keyword) @font-lock-keyword-face)
     (using_form keyword: (using_keyword) @font-lock-keyword-face))

   :language 'jerboa
   :feature 'keyword
   '((list . (symbol) @font-lock-keyword-face
      (:match "^\\(begin\\|begin0\\|do\\|set!\\|and\\|or\\|not\\|values\\|apply\\|eval\\|error\\|raise\\|guard\\|call/cc\\|call/values\\|let/cc\\|let/esc\\|unwind-protect\\|with-resource\\|while\\|until\\|dotimes\\|assert!\\|awhen\\|aif\\|when-let\\|if-let\\|catch\\|finally\\|where\\|cut\\|with\\|with\\*\\|rec\\|syntax-case\\|with-syntax\\|with-mutex\\|critical-section\\|foreign-procedure\\|with-exception-handler\\|dynamic-wind\\|with-input-from-string\\|with-output-to-string\\|with-input-from-file\\|with-output-to-file\\)$"
             @font-lock-keyword-face)))

   ;; Threading macros
   :language 'jerboa
   :feature 'keyword
   '((list . (symbol) @font-lock-keyword-face
      (:match "^\\(->\\|->>\\|as->\\|some->\\|cond->\\|->\\?\\)$"
             @font-lock-keyword-face)))

   ;; Result type keywords
   :language 'jerboa
   :feature 'keyword
   '((list . (symbol) @font-lock-keyword-face
      (:match "^\\(ok\\|err\\|ok\\?\\|err\\?\\|unwrap\\|unwrap-or\\|map-ok\\|map-err\\|and-then\\|try-result\\|try-result\\*\\|sequence-results\\)$"
             @font-lock-keyword-face)))

   ;; Iterator keywords
   :language 'jerboa
   :feature 'keyword
   '((list . (symbol) @font-lock-keyword-face
      (:match "^\\(in-list\\|in-vector\\|in-string\\|in-range\\|in-hash-keys\\|in-hash-values\\|in-hash-pairs\\|in-naturals\\|in-indexed\\|in-port\\|in-lines\\|in-chars\\|in-bytes\\|in-producer\\)$"
             @font-lock-keyword-face)))

   ;; Level 3: definitions (names)
   :language 'jerboa
   :feature 'definition
   '((definition name: (symbol) @font-lock-function-name-face)
     (method_definition name: (symbol) @font-lock-function-name-face)
     (type_definition name: (symbol) @font-lock-type-face)
     (enum_definition name: (symbol) @font-lock-type-face)
     (macro_definition name: (symbol) @font-lock-variable-name-face)
     (module_form name: (symbol) @font-lock-variable-name-face))

   ;; Level 4: builtins
   :language 'jerboa
   :feature 'builtin
   '((list . (symbol) @font-lock-builtin-face
      (:match "^\\(cons\\|car\\|cdr\\|list\\|append\\|reverse\\|length\\|null\\?\\|pair\\?\\|list\\?\\|flatten\\|unique\\|distinct\\|take\\|drop\\|every\\|any\\|filter\\|filter-map\\|group-by\\|zip\\|frequencies\\|partition\\|sort\\|sort!\\|map\\|for-each\\|foldl\\|foldr\\|display\\|displayln\\|newline\\|write\\|print\\|read\\|get-line\\|pp\\|pprint\\|format\\|printf\\|make-hash-table\\|hash-put!\\|hash-ref\\|hash-get\\|hash-key\\?\\|hash-remove!\\|hash->list\\|hash-keys\\|hash-values\\|hash-for-each\\|list->hash-table\\|string-split\\|string-join\\|string-trim\\|string-prefix\\?\\|string-suffix\\?\\|string-contains\\|string-empty\\?\\|str\\|string-append\\|substring\\|string-length\\|string->number\\|number->string\\|string->symbol\\|symbol->string\\|string->json-object\\|json-object->string\\|path-join\\|path-directory\\|path-extension\\|path-expand\\|compose\\|comp\\|partial\\|complement\\|negate\\|identity\\|constantly\\|curry\\|flip\\|conjoin\\|disjoin\\|juxt\\|read-file-string\\|read-file-lines\\|write-file-string\\|void\\|gensym\\|iota\\|random\\)$"
             @font-lock-builtin-face)))

   ;; Dispatch operator ~
   :language 'jerboa
   :feature 'builtin
   '((list . (symbol) @font-lock-builtin-face
      (:match "^~$" @font-lock-builtin-face)))

   ;; Level 5: constants and literals
   :language 'jerboa
   :feature 'constant
   '((boolean) @font-lock-constant-face
     (number) @font-lock-number-face)

   ;; Keywords (name: and #:name)
   :language 'jerboa
   :feature 'property
   '((keyword) @font-lock-property-use-face)

   ;; Level 6: types (predicates ending in ?)
   :language 'jerboa
   :feature 'type
   :override t
   '((list . (symbol) @font-lock-type-face
      (:match "\\?$" @font-lock-type-face)))

   ;; Level 7: brackets
   :language 'jerboa
   :feature 'bracket
   '((bracket_list "[" @font-lock-bracket-face)
     (bracket_list "]" @font-lock-bracket-face)
     (brace_list "{" @font-lock-bracket-face)
     (brace_list "}" @font-lock-bracket-face)
     (list "(" @font-lock-bracket-face)
     (list ")" @font-lock-bracket-face))

   ;; Level 8: function calls (fallback — head of list)
   :language 'jerboa
   :feature 'function
   '((list . (symbol) @font-lock-function-call-face))

   ;; Operators / special symbols
   :language 'jerboa
   :feature 'operator
   '(((symbol) @font-lock-operator-face
      (:match "^\\(=>\\|\\.\\.\\.\\|_\\|<>\\)$" @font-lock-operator-face)))
   )
  "Tree-sitter font-lock settings for `jerboa-ts-mode'.")

;; ---------------------------------------------------------------------------
;; Indentation
;; ---------------------------------------------------------------------------

(defvar jerboa-ts-mode--indent-rules
  `((jerboa
     ;; Top-level forms: no indent
     ((parent-is "source_file") column-0 0)

     ;; Special forms indent their body by 2
     ((node-is "definition") parent-bol 0)
     ((parent-is "definition") parent-bol 2)
     ((parent-is "type_definition") parent-bol 2)
     ((parent-is "method_definition") parent-bol 2)
     ((parent-is "macro_definition") parent-bol 2)
     ((parent-is "enum_definition") parent-bol 2)
     ((parent-is "lambda_form") parent-bol 2)
     ((parent-is "let_form") parent-bol 2)
     ((parent-is "if_form") parent-bol 2)
     ((parent-is "cond_form") parent-bol 2)
     ((parent-is "match_form") parent-bol 2)
     ((parent-is "for_form") parent-bol 2)
     ((parent-is "try_form") parent-bol 2)
     ((parent-is "using_form") parent-bol 2)
     ((parent-is "import_form") parent-bol 2)
     ((parent-is "module_form") parent-bol 2)

     ;; Generic list: align with first element or indent by 1
     ((parent-is "list") parent-bol 2)
     ((parent-is "bracket_list") parent-bol 1)
     ((parent-is "brace_list") parent-bol 1)
     ((parent-is "vector") parent-bol 1)

     ;; Closing paren
     ((node-is ")") parent-bol 0)
     ((node-is "]") parent-bol 0)
     ((node-is "}") parent-bol 0)

     ;; Catch-all
     (catch-all parent-bol 0)))
  "Tree-sitter indentation rules for `jerboa-ts-mode'.")

;; ---------------------------------------------------------------------------
;; Imenu (navigation)
;; ---------------------------------------------------------------------------

(defun jerboa-ts-mode--defun-name (node)
  "Return the name of the definition at NODE."
  (treesit-node-text
   (treesit-node-child-by-field-name node "name")
   t))

(defvar jerboa-ts-mode--imenu-settings
  '(("Function" "\\`definition\\'" nil nil)
    ("Type" "\\`\\(?:type_definition\\|enum_definition\\)\\'" nil nil)
    ("Method" "\\`method_definition\\'" nil nil)
    ("Macro" "\\`macro_definition\\'" nil nil)
    ("Module" "\\`module_form\\'" nil nil))
  "Imenu categories for `jerboa-ts-mode'.")

;; ---------------------------------------------------------------------------
;; Mode definition
;; ---------------------------------------------------------------------------

;;;###autoload
(define-derived-mode jerboa-ts-mode prog-mode "Jerboa"
  "Tree-sitter powered major mode for Jerboa Scheme.

Requires a tree-sitter grammar for Jerboa.  Install it with:

  (add-to-list \\='treesit-language-source-alist
               \\='(jerboa \"https://github.com/ober/jerboa-ts-mode\"))
  (treesit-install-language-grammar \\='jerboa)

\\{jerboa-ts-mode-map}"
  :syntax-table scheme-mode-syntax-table

  (unless (treesit-ready-p 'jerboa)
    (error "Tree-sitter grammar for Jerboa is not available"))

  (treesit-parser-create 'jerboa)

  ;; Comments
  (setq-local comment-start ";; ")
  (setq-local comment-end "")
  (setq-local comment-start-skip ";+\\s-*")

  ;; Font-lock
  (setq-local treesit-font-lock-settings jerboa-ts-mode--font-lock-settings)
  (setq-local treesit-font-lock-feature-list
              '((comment string)
                (keyword definition)
                (builtin constant property)
                (type bracket function operator)))

  ;; Indentation
  (setq-local treesit-simple-indent-rules jerboa-ts-mode--indent-rules)

  ;; Imenu / navigation
  (setq-local treesit-defun-type-regexp
              (regexp-opt '("definition" "type_definition" "method_definition"
                            "macro_definition" "enum_definition" "module_form")))
  (setq-local treesit-defun-name-function #'jerboa-ts-mode--defun-name)
  (setq-local treesit-simple-imenu-settings jerboa-ts-mode--imenu-settings)

  ;; REPL
  (setq-local scheme-program-name
              (mapconcat #'identity
                         (cons jerboa-ts-program-name jerboa-ts-program-args)
                         " "))

  (treesit-major-mode-setup))

;; ---------------------------------------------------------------------------
;; Auto-mode
;; ---------------------------------------------------------------------------

;;;###autoload
(progn
  (add-to-list 'auto-mode-alist '("\\.ss\\'" . jerboa-ts-mode))
  (add-to-list 'auto-mode-alist '("\\.sls\\'" . jerboa-ts-mode))
  (modify-coding-system-alist 'file "\\.ss\\'" 'utf-8)
  (modify-coding-system-alist 'file "\\.sls\\'" 'utf-8))

(provide 'jerboa-ts-mode)

;;; jerboa-ts-mode.el ends here
