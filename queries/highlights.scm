; Jerboa tree-sitter highlights
; Used by both Emacs treesit and other tree-sitter consumers (Neovim, Helix, etc.)

; ---------------------------------------------------------------
; Definition keywords
; ---------------------------------------------------------------
(definition keyword: (def_keyword) @keyword)
(definition name: (symbol) @function)

(type_definition keyword: (type_keyword) @keyword)
(type_definition name: (symbol) @type)

(method_definition keyword: (method_keyword) @keyword)
(method_definition name: (symbol) @function.method)

(macro_definition keyword: (macro_keyword) @keyword)
(macro_definition name: (symbol) @function.macro)

(enum_definition keyword: (enum_keyword) @keyword)
(enum_definition name: (symbol) @type)

(import_form keyword: (import_keyword) @keyword.import)
(module_form keyword: (module_keyword) @keyword)
(module_form name: (symbol) @module)

(lambda_form keyword: (lambda_keyword) @keyword.function)
(let_form keyword: (let_keyword) @keyword)
(if_form keyword: (conditional_keyword) @keyword.conditional)
(cond_form keyword: (cond_keyword) @keyword.conditional)
(match_form keyword: (match_keyword) @keyword)
(for_form keyword: (for_keyword) @keyword.repeat)
(try_form keyword: (try_keyword) @keyword.exception)
(using_form keyword: (using_keyword) @keyword)

; ---------------------------------------------------------------
; Known keywords in plain lists — catch symbols used as head of (...)
; ---------------------------------------------------------------
(list . (symbol) @keyword
 (#match? @keyword "^(begin|begin0|do|set!|and|or|not|cond-expand|values|apply|eval|error|raise|guard|with-exception-handler|dynamic-wind|call/cc|call/values|call-with-current-continuation|let/cc|let/esc|unwind-protect|with-resource|while|until|dotimes|assert!|awhen|aif|when-let|if-let|with-input-from-string|with-output-to-string|with-input-from-file|with-output-to-file|with-mutex|critical-section|catch|finally|where|cut|with|rec|syntax-case|with-syntax|foreign-procedure)$"))

; Threading macros
(list . (symbol) @keyword.operator
 (#match? @keyword.operator "^(->|->>|as->|some->|cond->|->\\?)$"))

; Result type
(list . (symbol) @keyword
 (#match? @keyword "^(ok|err|ok\\?|err\\?|unwrap|unwrap-or|map-ok|map-err|and-then|try-result|try-result\\*|sequence-results)$"))

; Testing
(list . (symbol) @keyword
 (#match? @keyword "^(test-suite|test-case|check|check-eq\\?|check-equal\\?|check-predicate|check-exception)$"))

; ---------------------------------------------------------------
; Builtins (functions from prelude)
; ---------------------------------------------------------------
(list . (symbol) @function.builtin
 (#match? @function.builtin "^(cons|car|cdr|list|append|reverse|length|null\\?|pair\\?|list\\?|assoc|assv|assq|member|memv|memq|flatten|unique|distinct|take|drop|take-last|drop-last|every|any|filter|filter-map|group-by|zip|frequencies|partition|interleave|mapcat|keep|split-at|append-map|snoc|sort|sort!|map|for-each|foldl|foldr|andmap|ormap|display|displayln|newline|write|print|read|get-line|pp|pprint|format|printf|fprintf|make-hash-table|hash-put!|hash-ref|hash-get|hash-key\\?|hash-remove!|hash->list|hash-keys|hash-values|hash-for-each|list->hash-table|string-split|string-join|string-trim|string-prefix\\?|string-suffix\\?|string-contains|string-empty\\?|str|string-upcase|string-downcase|string-append|substring|string-length|string-ref|string->number|number->string|string->symbol|symbol->string|string->json-object|json-object->string|path-join|path-directory|path-extension|path-absolute\\?|path-expand|compose|comp|partial|complement|negate|identity|constantly|curry|flip|conjoin|disjoin|juxt|read-file-string|read-file-lines|write-file-string|vector|make-vector|vector-ref|vector-set!|vector-length|vector->list|list->vector|void|gensym|iota|random|datetime-now|datetime-utc-now|make-datetime|parse-datetime)$"))

; Dispatch operator
(list . (symbol) @operator
 (#match? @operator "^~$"))

; ---------------------------------------------------------------
; Atoms
; ---------------------------------------------------------------
(number) @number
(string) @string
(character) @character
(boolean) @boolean
(keyword) @property
(heredoc) @string

; ---------------------------------------------------------------
; Brackets
; ---------------------------------------------------------------
(bracket_list "[" @punctuation.bracket)
(bracket_list "]" @punctuation.bracket)
(brace_list "{" @punctuation.bracket)
(brace_list "}" @punctuation.bracket)
(list "(" @punctuation.bracket)
(list ")" @punctuation.bracket)
(vector "#(" @punctuation.bracket)

; ---------------------------------------------------------------
; Predicates (name?) and mutators (name!)
; ---------------------------------------------------------------
((symbol) @type
 (#match? @type "\\?$"))

((symbol) @function.builtin
 (#match? @function.builtin "!$"))

; ---------------------------------------------------------------
; Special symbols
; ---------------------------------------------------------------
((symbol) @operator
 (#match? @operator "^(=>|\\.\\.\\.|_|<>|<\\.\\.\\.>)$"))

; ---------------------------------------------------------------
; Quote/unquote
; ---------------------------------------------------------------
(quote) @string.special
(quasiquote) @string.special
(unquote) @punctuation.special
(unquote_splicing) @punctuation.special

; ---------------------------------------------------------------
; Comments
; ---------------------------------------------------------------
(comment) @comment
(block_comment) @comment
(datum_comment) @comment
(directive) @keyword.directive

; ---------------------------------------------------------------
; Fallback: any symbol at head of list is a function call
; ---------------------------------------------------------------
(list . (symbol) @function.call)
