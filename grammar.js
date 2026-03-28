/// <reference types="tree-sitter-cli/dsl" />

module.exports = grammar({
  name: "jerboa",

  extras: ($) => [/\s/, $.comment, $.block_comment],

  word: ($) => $.symbol,

  externals: ($) => [$.heredoc, $.block_comment],

  conflicts: ($) => [],

  rules: {
    source_file: ($) => repeat(choice($._datum, $.directive)),

    // #!/usr/bin/env scheme-script, #!chezscheme, #!eof, #!r6rs, etc.
    directive: (_$) => token(seq("#!", /[^\n]*/)),

    // ---------------------------------------------------------------
    // Top-level datum — anything that can appear at any nesting level
    // ---------------------------------------------------------------
    _datum: ($) =>
      choice(
        $._atom,
        $.list,
        $.bracket_list,
        $.brace_list,
        $.vector,
        $.bytevector,
        $.quote,
        $.quasiquote,
        $.unquote,
        $.unquote_splicing,
        $.syntax_quote,
        $.quasisyntax,
        $.unsyntax,
        $.unsyntax_splicing,
        $.datum_comment,
        $.heredoc,
        $.block_comment
      ),

    // ---------------------------------------------------------------
    // Atoms
    // ---------------------------------------------------------------
    _atom: ($) =>
      choice($.number, $.string, $.character, $.boolean, $.symbol, $.keyword),

    number: (_$) =>
      token(
        choice(
          // integers (with optional radix)
          /[+-]?[0-9]+/,
          /#[bodxBODX][0-9a-fA-F]+/,
          // rationals
          /[+-]?[0-9]+\/[0-9]+/,
          // floats
          /[+-]?[0-9]*\.[0-9]+([eE][+-]?[0-9]+)?/,
          /[+-]?[0-9]+\.[0-9]*([eE][+-]?[0-9]+)?/,
          /[+-]?[0-9]+[eE][+-]?[0-9]+/,
          // exact/inexact prefix
          /#[eiEI](#[bodxBODX])?[+-]?[0-9]*\.?[0-9]+([eE][+-]?[0-9]+)?/,
          // +inf.0 -inf.0 +nan.0
          /[+-](inf|nan)\.0/
        )
      ),

    string: (_$) =>
      token(seq('"', repeat(choice(/[^"\\]/, /\\./)), '"')),

    character: (_$) =>
      token(
        choice(
          /#\\./,                         // #\a
          /#\\(space|newline|tab|return|nul|alarm|backspace|delete|escape|vtab)/,
          /#\\x[0-9a-fA-F]+/             // #\x41
        )
      ),

    boolean: (_$) => token(choice("#t", "#f", "#true", "#false")),

    // Jerboa keywords: name: or #:name
    keyword: (_$) =>
      token(
        choice(
          /#:[a-zA-Z_!?<>=*/+\-][a-zA-Z0-9_!?<>=*/+\-.]*/,
          /[a-zA-Z_!?<>=*/+\-][a-zA-Z0-9_!?<>=*/+\-]*:/
        )
      ),

    symbol: (_$) =>
      token(
        choice(
          /[a-zA-Z_!?<>=*/+\-^&~%@][a-zA-Z0-9_!?<>=*/+\-^&~%@.]*/,
          /\|[^|]*\|/,                   // |escaped symbol|
          /\.\.\./                        // ellipsis
        )
      ),

    // ---------------------------------------------------------------
    // Compound forms
    // ---------------------------------------------------------------

    // Standard parens: (...)
    list: ($) =>
      choice(
        $._special_form,
        seq("(", repeat($._datum), optional(seq("." , $._datum)), ")")
      ),

    // Jerboa reader syntax: [...] → (list ...)
    bracket_list: ($) => seq("[", repeat($._datum), "]"),

    // Jerboa reader syntax: {...} → method dispatch
    brace_list: ($) => seq("{", repeat($._datum), "}"),

    // #(...) vector literal
    vector: ($) => seq("#(", repeat($._datum), ")"),

    // #vu8(...) bytevector
    bytevector: ($) => seq(choice("#vu8(", "#u8("), repeat($._datum), ")"),

    // ---------------------------------------------------------------
    // Special forms — recognized structurally for better highlighting
    // ---------------------------------------------------------------
    _special_form: ($) =>
      choice(
        $.definition,
        $.type_definition,
        $.method_definition,
        $.macro_definition,
        $.enum_definition,
        $.import_form,
        $.module_form,
        $.lambda_form,
        $.let_form,
        $.if_form,
        $.cond_form,
        $.match_form,
        $.for_form,
        $.try_form,
        $.using_form
      ),

    // (def (name args...) body) | (def name expr)
    definition: ($) =>
      seq(
        "(",
        field("keyword", alias(choice("def", "def*", "define", "defvalues", "defgeneric"), $.def_keyword)),
        choice(
          seq("(", field("name", $.symbol), repeat($._datum), ")"),
          field("name", $.symbol)
        ),
        repeat($._datum),
        ")"
      ),

    // (defstruct name (fields...)) | (defstruct (child parent) (fields...))
    // (defclass ...) | (defrecord ...)
    type_definition: ($) =>
      seq(
        "(",
        field("keyword", alias(choice("defstruct", "defclass", "defrecord"), $.type_keyword)),
        field("name", choice(
          $.symbol,
          seq("(", $.symbol, $.symbol, ")")  // (child parent)
        )),
        repeat($._datum),
        ")"
      ),

    // (defmethod (name (self type)) body)
    method_definition: ($) =>
      seq(
        "(",
        field("keyword", alias("defmethod", $.method_keyword)),
        "(",
        field("name", $.symbol),
        repeat($._datum),
        ")",
        repeat($._datum),
        ")"
      ),

    // (defrule (name pattern) template) | (defsyntax name transformer)
    macro_definition: ($) =>
      seq(
        "(",
        field("keyword", alias(choice("defrule", "defrules", "defsyntax", "define-syntax"), $.macro_keyword)),
        choice(
          seq("(", field("name", $.symbol), repeat($._datum), ")"),
          field("name", $.symbol)
        ),
        repeat($._datum),
        ")"
      ),

    // (define-enum name (variants...))
    enum_definition: ($) =>
      seq(
        "(",
        field("keyword", alias("define-enum", $.enum_keyword)),
        field("name", $.symbol),
        repeat($._datum),
        ")"
      ),

    // (import (jerboa prelude) (std net request))
    import_form: ($) =>
      seq(
        "(",
        field("keyword", alias(choice("import", "export"), $.import_keyword)),
        repeat($._datum),
        ")"
      ),

    // (module name body...)
    module_form: ($) =>
      seq(
        "(",
        field("keyword", alias("module", $.module_keyword)),
        field("name", $.symbol),
        repeat($._datum),
        ")"
      ),

    // (lambda (args) body) | (case-lambda clauses)
    lambda_form: ($) =>
      seq(
        "(",
        field("keyword", alias(choice("lambda", "case-lambda"), $.lambda_keyword)),
        repeat($._datum),
        ")"
      ),

    // (let ((bindings)) body) and variants
    let_form: ($) =>
      seq(
        "(",
        field("keyword", alias(
          choice("let", "let*", "letrec", "letrec*",
                 "let-values", "letrec-values",
                 "parameterize", "fluid-let",
                 "when-let", "if-let", "alet", "alet*"),
          $.let_keyword)),
        repeat($._datum),
        ")"
      ),

    // (if test then else)
    if_form: ($) =>
      seq(
        "(",
        field("keyword", alias(
          choice("if", "when", "unless", "cond->", "aif", "awhen"),
          $.conditional_keyword)),
        repeat($._datum),
        ")"
      ),

    // (cond clauses...)
    cond_form: ($) =>
      seq(
        "(",
        field("keyword", alias(choice("cond", "case"), $.cond_keyword)),
        repeat($._datum),
        ")"
      ),

    // (match expr clauses...)
    match_form: ($) =>
      seq(
        "(",
        field("keyword", alias(choice("match", "match*"), $.match_keyword)),
        repeat($._datum),
        ")"
      ),

    // (for ((x (in-range 5))) body) and variants
    for_form: ($) =>
      seq(
        "(",
        field("keyword", alias(
          choice("for", "for*", "for/collect", "for/fold", "for/or", "for/and"),
          $.for_keyword)),
        repeat($._datum),
        ")"
      ),

    // (try body (catch ...) (finally ...))
    try_form: ($) =>
      seq(
        "(",
        field("keyword", alias("try", $.try_keyword)),
        repeat($._datum),
        ")"
      ),

    // (using (var expr : type?) body)
    using_form: ($) =>
      seq(
        "(",
        field("keyword", alias("using", $.using_keyword)),
        repeat($._datum),
        ")"
      ),

    // ---------------------------------------------------------------
    // Quote forms
    // ---------------------------------------------------------------
    quote: ($) => seq("'", $._datum),
    quasiquote: ($) => seq("`", $._datum),
    unquote: ($) => seq(",", $._datum),
    unquote_splicing: ($) => seq(",@", $._datum),
    syntax_quote: ($) => seq("#'", $._datum),
    quasisyntax: ($) => seq("#`", $._datum),
    unsyntax: ($) => seq("#,", $._datum),
    unsyntax_splicing: ($) => seq("#,@", $._datum),

    // ---------------------------------------------------------------
    // Datum comment: #; datum
    // ---------------------------------------------------------------
    datum_comment: ($) => seq("#;", $._datum),

    // heredoc and block_comment are handled by the external scanner (src/scanner.c)

    // ---------------------------------------------------------------
    // Comments
    // ---------------------------------------------------------------
    comment: (_$) => token(seq(";", /.*/)),
  },
});
