// External scanner for tree-sitter-jerboa
// Handles: heredoc strings (#<<DELIM\n...\nDELIM) and block comments (#|...|#)

#include "tree_sitter/parser.h"
#include <string.h>

enum TokenType {
  HEREDOC,
  BLOCK_COMMENT,
};

// Maximum delimiter length for heredocs
#define MAX_DELIM 256

void *tree_sitter_jerboa_external_scanner_create(void) {
  return NULL;
}

void tree_sitter_jerboa_external_scanner_destroy(void *payload) {
  (void)payload;
}

unsigned tree_sitter_jerboa_external_scanner_serialize(void *payload, char *buffer) {
  (void)payload;
  (void)buffer;
  return 0;
}

void tree_sitter_jerboa_external_scanner_deserialize(void *payload, const char *buffer, unsigned length) {
  (void)payload;
  (void)buffer;
  (void)length;
}

static bool scan_heredoc(TSLexer *lexer) {
  // We expect to be positioned at '#'
  // Match: #<<DELIM\n ... \nDELIM\n (or EOF)
  if (lexer->lookahead != '#') return false;
  lexer->advance(lexer, false);

  if (lexer->lookahead != '<') return false;
  lexer->advance(lexer, false);

  if (lexer->lookahead != '<') return false;
  lexer->advance(lexer, false);

  // Read delimiter name
  char delim[MAX_DELIM];
  int delim_len = 0;

  // First char must be alpha or _
  if (!(  (lexer->lookahead >= 'A' && lexer->lookahead <= 'Z') ||
          (lexer->lookahead >= 'a' && lexer->lookahead <= 'z') ||
          lexer->lookahead == '_')) {
    return false;
  }

  while ((lexer->lookahead >= 'A' && lexer->lookahead <= 'Z') ||
         (lexer->lookahead >= 'a' && lexer->lookahead <= 'z') ||
         (lexer->lookahead >= '0' && lexer->lookahead <= '9') ||
         lexer->lookahead == '_') {
    if (delim_len >= MAX_DELIM - 1) return false;
    delim[delim_len++] = (char)lexer->lookahead;
    lexer->advance(lexer, false);
  }
  delim[delim_len] = '\0';

  if (delim_len == 0) return false;

  // Expect newline after delimiter
  if (lexer->lookahead != '\n') return false;
  lexer->advance(lexer, false);

  // Scan body until we find \nDELIM at start of line
  for (;;) {
    if (lexer->eof(lexer)) {
      // Unterminated heredoc — still produce the token
      lexer->result_symbol = HEREDOC;
      return true;
    }

    // Check if current position starts with the delimiter
    bool at_line_start = true;  // We just consumed a \n or are scanning line-by-line
    int match_pos = 0;

    // Try to match delimiter at current position (start of line)
    while (match_pos < delim_len) {
      if (lexer->eof(lexer) || lexer->lookahead != delim[match_pos]) {
        at_line_start = false;
        break;
      }
      match_pos++;
      lexer->advance(lexer, false);
    }

    if (at_line_start && match_pos == delim_len) {
      // Check that delimiter is followed by newline or EOF or whitespace/paren
      if (lexer->eof(lexer) || lexer->lookahead == '\n' ||
          lexer->lookahead == '\r' || lexer->lookahead == ' ' ||
          lexer->lookahead == ')' || lexer->lookahead == ']') {
        lexer->result_symbol = HEREDOC;
        return true;
      }
    }

    // Skip to next newline
    while (!lexer->eof(lexer) && lexer->lookahead != '\n') {
      lexer->advance(lexer, false);
    }
    if (!lexer->eof(lexer)) {
      lexer->advance(lexer, false);  // consume the \n
    }
  }
}

static bool scan_block_comment(TSLexer *lexer) {
  // Match: #| ... |#  (with nesting support)
  if (lexer->lookahead != '#') return false;
  lexer->advance(lexer, false);

  if (lexer->lookahead != '|') return false;
  lexer->advance(lexer, false);

  int depth = 1;

  while (depth > 0) {
    if (lexer->eof(lexer)) {
      // Unterminated — still produce the token
      lexer->result_symbol = BLOCK_COMMENT;
      return true;
    }

    if (lexer->lookahead == '#') {
      lexer->advance(lexer, false);
      if (lexer->lookahead == '|') {
        lexer->advance(lexer, false);
        depth++;
        continue;
      }
      continue;
    }

    if (lexer->lookahead == '|') {
      lexer->advance(lexer, false);
      if (lexer->lookahead == '#') {
        lexer->advance(lexer, false);
        depth--;
        continue;
      }
      continue;
    }

    lexer->advance(lexer, false);
  }

  lexer->result_symbol = BLOCK_COMMENT;
  return true;
}

bool tree_sitter_jerboa_external_scanner_scan(void *payload, TSLexer *lexer, const bool *valid_symbols) {
  (void)payload;

  // Skip whitespace
  while (lexer->lookahead == ' ' || lexer->lookahead == '\t' ||
         lexer->lookahead == '\r' || lexer->lookahead == '\n') {
    lexer->advance(lexer, true);
  }

  if (lexer->lookahead == '#') {
    // Save position by marking
    lexer->mark_end(lexer);

    // Peek ahead
    lexer->advance(lexer, false);

    if (lexer->lookahead == '<' && valid_symbols[HEREDOC]) {
      // Reset — scan_heredoc expects to start at '#'
      // We can't easily reset, so let's restructure:
      // Actually, we already consumed '#', let's check for '<<'
      lexer->advance(lexer, false);  // consume first '<'
      if (lexer->lookahead == '<') {
        lexer->advance(lexer, false);  // consume second '<'

        // Read delimiter
        char delim[MAX_DELIM];
        int delim_len = 0;

        if (!(  (lexer->lookahead >= 'A' && lexer->lookahead <= 'Z') ||
                (lexer->lookahead >= 'a' && lexer->lookahead <= 'z') ||
                lexer->lookahead == '_')) {
          return false;
        }

        while ((lexer->lookahead >= 'A' && lexer->lookahead <= 'Z') ||
               (lexer->lookahead >= 'a' && lexer->lookahead <= 'z') ||
               (lexer->lookahead >= '0' && lexer->lookahead <= '9') ||
               lexer->lookahead == '_') {
          if (delim_len >= MAX_DELIM - 1) return false;
          delim[delim_len++] = (char)lexer->lookahead;
          lexer->advance(lexer, false);
        }
        delim[delim_len] = '\0';

        if (delim_len == 0) return false;
        if (lexer->lookahead != '\n') return false;
        lexer->advance(lexer, false);

        // Scan body line by line
        for (;;) {
          if (lexer->eof(lexer)) {
            lexer->mark_end(lexer);
            lexer->result_symbol = HEREDOC;
            return true;
          }

          // Try matching delimiter at start of line
          int match_pos = 0;
          bool matched = true;
          while (match_pos < delim_len) {
            if (lexer->eof(lexer) || (int)lexer->lookahead != delim[match_pos]) {
              matched = false;
              break;
            }
            match_pos++;
            lexer->advance(lexer, false);
          }

          if (matched && match_pos == delim_len) {
            if (lexer->eof(lexer) || lexer->lookahead == '\n' ||
                lexer->lookahead == '\r' || lexer->lookahead == ' ' ||
                lexer->lookahead == ')' || lexer->lookahead == ']') {
              lexer->mark_end(lexer);
              lexer->result_symbol = HEREDOC;
              return true;
            }
          }

          // Skip to end of line
          while (!lexer->eof(lexer) && lexer->lookahead != '\n') {
            lexer->advance(lexer, false);
          }
          if (!lexer->eof(lexer)) {
            lexer->advance(lexer, false);
          }
        }
      }
      return false;
    }

    if (lexer->lookahead == '|' && valid_symbols[BLOCK_COMMENT]) {
      lexer->advance(lexer, false);  // consume '|'
      int depth = 1;

      while (depth > 0) {
        if (lexer->eof(lexer)) {
          lexer->mark_end(lexer);
          lexer->result_symbol = BLOCK_COMMENT;
          return true;
        }

        if (lexer->lookahead == '#') {
          lexer->advance(lexer, false);
          if (!lexer->eof(lexer) && lexer->lookahead == '|') {
            lexer->advance(lexer, false);
            depth++;
            continue;
          }
          continue;
        }

        if (lexer->lookahead == '|') {
          lexer->advance(lexer, false);
          if (!lexer->eof(lexer) && lexer->lookahead == '#') {
            lexer->advance(lexer, false);
            depth--;
            continue;
          }
          continue;
        }

        lexer->advance(lexer, false);
      }

      lexer->mark_end(lexer);
      lexer->result_symbol = BLOCK_COMMENT;
      return true;
    }
  }

  return false;
}
