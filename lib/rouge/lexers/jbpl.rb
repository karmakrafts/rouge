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
        typeof opcodeof sizeof
        yeet inject field fun class macro
        public protected private static sync final transient volatile
        info error assert version define include
        if else when for break continue default
        this is as in by
      ]

      prepro_type_keywords = %w[type opcode instruction signature]
      int_types = %w[i8 i16 i32 i64]
      float_types = %w[f32 f64]
      type_keywords = %w[void char bool string] + int_types + float_types
      constant_keywords = %w[true false]
      special_keywords = %w[\^return \^class]

      name = %r'[a-zA-Z_]+[a-zA-Z0-9_$]*'
      punctuation = %r'[$~!%^&*()+=|\[\]:,.<>/?-]'

      float_literal = %r'[0-9]+[0-9_]*(\.[0-9]+[0-9_]*)?([eE][0-9]+[0-9_]*)?'
      dec_literal = %r'[0-9]+[0-9_]*'
      bin_literal = %r'0[bB][01]+[01_]*'
      hex_literal = %r'0[xX][0-9a-fA-F]+[0-9a-fA-F_]*'
      oct_literal = %r'0[oO][0-7]+[0-7_]*'

      const_insn = %r'ldc|([bs]ipush)|(iconst_(m1|[012345]))|(lconst_[01])|(fconst_[012])|(dconst_[01])|aconst_null'
      stack_insn = %r'[ilfda](load|store)|(dup(2)?(_x[12])?)|(pop(2)?)'
      field_insn = %r'(get(field|static))|(put(field|static))'
      jump_insn = %r'goto|jsr|ret'
      conv_insn = %r'(i2[bcdfls])|(f2[dil])|(d2[fil])|(l2[dfi])'
      logic_insn = %r'([il](ushr|shl|shr|and|xor|or))'
      arith_insn = %r'([ilfd](add|sub|mul|div|rem|neg))'
      array_insn = %r'multianewarray|arraylength|anewarray|([ilfdacsz]newarray)|([ilfda]aload)|([ilfda]astore)'
      misc_insn = %r'(monitor(enter|exit))|athrow|iinc|nop'
      ctrl_insn = %r'((lookup|table)switch)|([ilfda]?return)'
      type_insn = %r'checkcast|instanceof|new'
      cond_insn = %r'(if_acmp(eq|ne))|(if(_icmp)?(eq|ne|lt|ge|gt|le))'
      invoke_insn = %r'(invoke(interface|virtual|static|special|dynamic))'

      insn = %r'(#{[
        const_insn, stack_insn, field_insn, jump_insn, conv_insn, type_insn, cond_insn,
        logic_insn, arith_insn, invoke_insn, array_insn, misc_insn, ctrl_insn
      ].join('|')})'

      class_type_name = %r'<#{name}(/#{name})*?>'

      state :root do
        mixin :body
      end

      state :body do
        rule %r'(\^class)(\s+)' do
          groups Keyword, Text
          push :prepro_class
        end
        rule %r'\b(fun)(\s+)(?![)=\s])' do
          groups Keyword, Text
          push :function
        end
        rule %r'\b(inject)(\s+)(?![)=\s])' do
          groups Keyword, Text
          push :function
        end
        rule %r'\b(macro)(\s+)' do
          groups Keyword, Text
          push :macro
        end
        rule %r'\b(field)(\s+)' do
          groups Keyword, Text
          push :field
        end
        rule %r'\b(define)(\s+)' do
          groups Keyword, Text
          push :define
        end
        rule %r'\b(type)(\s+)(#{name})' do
          groups Keyword, Text, Name::Class
        end
        rule %r'\b(by)(\s+)' do
          groups Keyword, Text
          push :selection
        end

        rule %r'\b(fun)(\s*)(\.)(\s*)(#{name})' do
          # Names in fun scope references
          groups Keyword, Text, Punctuation, Text, Name::Variable
        end

        rule %r'\b(field)(\s*)(\.)(\s*)(#{name})' do
          # Names in field scope references
          groups Keyword, Text, Punctuation, Text, Name::Variable
        end

        rule %r'(\.)(\s*)(#{name})(\s*)(?=:)' do
          # Names in field signatures
          groups Punctuation, Text, Name::Variable::Instance, Text
        end
        rule %r'(\.)(\s*)(#{name})(\s*)(?=\()' do
          # Names in function signatures
          groups Punctuation, Text, Name::Function, Text
        end

        rule %r'(?:#{special_keywords.join('|')})\b', Keyword
        rule %r'\b(?:#{keywords.join('|')})\b', Keyword
        rule %r'\b(?:#{prepro_type_keywords.join('|')})\b', Keyword
        rule %r'\b(?:#{type_keywords.join('|')})\b', Keyword::Type
        rule %r'\b(?:#{constant_keywords.join('|')})\b', Keyword::Constant

        rule %r'\b(?:#{insn})\b', Operator::Word # instructions

        rule %r'[^\S\n]+', Text
        rule %r'\\\n', Text # line continuation
        rule %r'//.*?$', Comment::Single
        rule %r'/[*].*[*]/', Comment::Multiline # single line block comment
        rule %r'/[*].*', Comment::Multiline, :comment # multiline block comment
        rule %r'\n', Text

        mixin :literal

        rule %r'(?<=[>}]\.)(#{name})(\()' do
          groups Name::Function, Punctuation
          push :macro_call
        end

        rule class_type_name, Name::Class # class types
        rule %r'\)', Punctuation, :pop!
        rule %r'\(', Punctuation, :body # Keep state steck symmetrical for parens
        rule %r']', Punctuation, :pop!
        rule %r'\[', Punctuation, :body
        rule %r'\$\{', Keyword, :lerp
        rule %r'\{', Punctuation
        rule %r'}', Punctuation
        rule punctuation, Punctuation
        rule name, Name::Variable
      end

      state :literal do
        rule %r'"'m, Literal::String::Double, :string
        rule %r"'\\.'|'[^\\]'", Str::Char
        rule %r'#{bin_literal}(#{int_types.join('|')})?', Literal::Number::Bin
        rule %r'#{hex_literal}(#{int_types.join('|')})?', Literal::Number::Hex
        rule %r'#{oct_literal}(#{int_types.join('|')})?', Literal::Number::Oct
        rule %r'#{float_literal}(#{float_types.join('|')})?', Literal::Number::Float
        rule %r'#{dec_literal}(#{int_types.join('|')})?', Literal::Number::Integer
      end

      state :selection do
        rule name, Name::Function, :pop!
      end

      state :prepro_class do
        rule name, Name::Class, :pop!
      end

      state :string_lerp do
        rule %r'}', Literal::String::Interpol, :pop!
        mixin :body
      end

      state :lerp do
        rule %r'}', Keyword, :pop!
        mixin :body
      end

      state :string do
        rule %r'"', Literal::String::Double, :pop!
        rule %r'\$\{', Literal::String::Interpol, :string_lerp
        rule %r'[^"${}]+', Literal::String::Double
      end

      state :macro do
        rule name, Name::Function, :pop!
        rule %r'\$\{', Keyword, [:pop!, :lerp]
      end

      state :macro_call do
        rule %r'\)', Punctuation, :pop!
        mixin :body
      end

      state :define do
        rule name, Name::Variable, :pop!
        rule %r'\$\{', Keyword, [:pop!, :lerp]
        rule punctuation, Punctuation
      end

      state :field do
        rule class_type_name, Name::Class # class types
        rule name, Name::Variable::Instance, :pop!
        rule %r'\$\{', Keyword, [:pop!, :lerp]
        rule punctuation, Punctuation
      end

      state :function do
        rule class_type_name, Name::Class # class types
        rule %r'(\.)(#{name})', Name::Function, :pop!
        rule %r'(\.)(<#{name}>)', Name::Function, :pop! # special function names
        rule %r'\$\{', Keyword, [:pop!, :lerp]
        rule punctuation, Punctuation
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