# -*- coding: utf-8 -*- #
# frozen_string_literal: true

module Rouge
  module Lexers
    class JBPL < RegexLexer
      # https://github.com/karmakrafts/JBPL/tree/master/jbpl-frontend/src/main/antlr

      title "JBPL"
      desc "Java Bytecode Patch Language (https://github.com/karmakrafts/JBPL)"

      tag 'jbpl'
      filenames '*.jbpl'
      mimetypes 'text/x-jbpl'

      keywords = %w[
        void i8 i16 i32 i64 f32 f64 char bool string
        type typeof opcode opcodeof instruction
        yeet inject field fun class
        public protected private static sync final transient volatile
        info error assert version define
        if else when for break continue true false default
        is as in by
      ]
      special_keywords = %w[\^return \^class]

      int_types = %w[i8 i16 i32 i64]
      float_types = %w[f32 f64]

      name = %r'[a-zA-Z_$]+[a-zA-Z0-9_$]*'
      arithmetic_ops = %r'[-+*/%]'
      logic_ops = %r'([|&^]|&&|(\|\|)|<<|>>>|>>)'
      range_ops = %r'((\.\.)|(\.\.<))'
      punctuation = %r'[~!%^&*()+=|\[\]:,.<>/?-]'

      float_literal = %r'[0-9]+[0-9_]*(\.[0-9]+[0-9_]*)?([eE][0-9]+[0-9_]*)?'
      dec_literal = %r'[0-9]+[0-9_]*'
      bin_literal = %r'0[bB][01]+[01_]*'
      hex_literal = %r'0[xX][0-9a-fA-F]+[0-9a-fA-F_]*'
      oct_literal = %r'0[oO][0-7]+[0-7_]*'

      state :root do
        mixin :body
      end

      state :body do
        rule %r'\b(fun)(\s+)' do
          groups Keyword, Text
          push :function
        end

        rule %r'\b(macro)(\s+)' do
          groups Keyword, Text
          push :function
        end

        rule %r'\b(field)(\s+)' do
          groups Keyword, Text
          push :field
        end

        rule %r'\b(define)(\s+)' do
          groups Keyword, Text
          push :define
        end

        rule %r'(?:#{special_keywords.join('|')})\b', Keyword
        rule %r'\b(?:#{keywords.join('|')})\b', Keyword
        rule %r'[^\S\n]+', Text
        rule %r'\\\n', Text # line continuation
        rule %r'//.*?$', Comment::Single
        rule %r'/[*].*[*]/', Comment::Multiline # single line block comment
        rule %r'/[*].*', Comment::Multiline, :comment # multiline block comment
        rule %r'\n', Text
        rule %r'#{bin_literal}(#{int_types.join('|')})?', Num::Bin
        rule %r'#{hex_literal}(#{int_types.join('|')})?', Num::Hex
        rule %r'#{oct_literal}(#{int_types.join('|')})?', Num::Oct
        rule %r'#{float_literal}(#{float_types.join('|')})?', Num::Float
        rule %r'#{dec_literal}(#{int_types.join('|')})?', Num::Integer

        rule %r'(#{name})(\()' do
          groups Name::Function, Punctuation
          push :macro_call
        end

        rule %r'<#{name}(/#{name})*?>', Name::Class # class types
        rule %r'#{arithmetic_ops}|#{logic_ops}|#{range_ops}', Operator
        rule %r'\)', Punctuation, :pop!
        rule %r'\(', Punctuation, :body # Keep state steck symmetrical for parens
        rule punctuation, Punctuation
        rule %r'[{}]', Punctuation
        rule %r'"'m, Str, :string
        rule %r"'\\.'|'[^\\]'", Str::Char
        rule name, Name
      end

      state :string do
        rule %r'"', Str, :pop!
        rule %r'\$\{', Keyword, :lerp
        rule %r'[^"${}]+', Str
      end

      state :lerp do
        rule %r'}', Keyword, :pop!
        mixin :body
      end

      state :macro do
        rule name, Name::Function, :pop!
      end

      state :macro_call do
        rule %r'\)', Punctuation, :pop!
        mixin :body
      end

      state :define do
        rule name, Name::Variable, :pop!
      end

      state :field do
        rule %r'<#{name}(/#{name})*?>', Name::Class # class types
        rule punctuation, Punctuation
        rule name, Name::Variable, :pop!
      end

      state :function do
        rule %r'<#{name}(/#{name})*?>', Name::Class # class types
        rule punctuation, Punctuation
        rule name, Name::Function, :pop!
      end

      state :comment do
        rule %r'/[*]', Comment::Multiline, :comment
        rule %r'[*]/', Comment::Multiline, :pop!
        rule %r'[^/*]+', Comment::Multiline
        rule %r'[/*]', Comment::Multiline
      end
    end
  end
end