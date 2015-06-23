require 'js_base/js_test'
require 'tokn'

class TestTokn4 < JSTest

  def test_ExpressionPrecedence

    tok =<<-'eos'
      WS: [\s\t\n]+
      # Double has lower priority than int; we want ints to
      # be interpreted as ints, not as doubles
      DBL: \-?((\d(.\d)?)|.\d)
      INT: \-?\d
    eos

    script =<<-'eos'
        5.2
        5
        -5.2
        -5
    eos

    verify(tok,script)
  end

  def test_ExpressionPrecedenceIncorrect

    tok =<<-'eos'
      WS: [\s\t\n]+
      # Here INT appears before DBL, which will cause no INTs to
      # be produced since every INT also matches a DBL, and DBL has higher precedence
      INT: \-?\d
      DBL: \-?((\d(.\d)?)|.\d)
    eos

    script =<<-'eos'
        5.2
        5
        -5.2
        -5
    eos

    verify(tok,script)
  end

  def test_dec
    tok =<<-'eos'
      DIGIT: \d
    eos
    script = "0123.456789/:AF"
    verify(tok,script,nil)
  end

  def test_w
    tok =<<-'eos'
      W: \w
    eos
    script = "/0189:@AZ[^_`az{"
    verify(tok,script,nil)
  end

  def test_bracketexpr
    tok =<<-'eos'
      C: [bcd]
    eos
    script = "abcde"
    verify(tok,script,nil)
  end

  def test_negated_bracketexpr
    tok =<<-'eos'
      C: [^bcd]
    eos
    script = "abcde"
    verify(tok,script,nil)
  end

  def test_bracketexpr_range
    tok =<<-'eos'
      C: [b-d]
    eos
    script = "abcde"
    verify(tok,script,nil)
  end

  def test_bracketexpr_range2
    tok =<<-'eos'
      C: [b-b]
    eos
    script = "abcde"
    verify(tok,script,nil)
  end

  def test_bracketexpr_range3
    tok =<<-'eos'
      C: [ac-df]
    eos
    script = "abcdefg"
    verify(tok,script,nil)
  end

  def test_bracketexpr_dec
    tok =<<-'eos'
      C: [\d]
    eos
    script = "abc09defg"
    verify(tok,script,nil)
  end

  def test_bracketexpr_word
    tok =<<-'eos'
      C: [\w]
    eos
    script = "./_?01_w#"
    verify(tok,script,nil)
  end

  def test_bracketexpr_dec_neg
    tok =<<-'eos'
      C: [^\d]
    eos
    script = "abc09defg"
    verify(tok,script,nil)
  end

  def test_bracketexpr_word_neg
    tok =<<-'eos'
      C: [^\w]
    eos
    script = "./_?01_w#"
    verify(tok,script,nil)
  end

  def test_negated_bracketexpr_range
    tok =<<-'eos'
      C: [^b-d]
    eos
    script = "abcde"
    verify(tok,script,nil)
  end

  def test_negated_bracketexpr_range2
    tok =<<-'eos'
      C: [b-b]
    eos
    script = "abcde"
    verify(tok,script,nil)
  end

  def test_negated_bracketexpr_range3
    tok =<<-'eos'
      C: [ac-df]
    eos
    script = "abcdefg"
    verify(tok,script,nil)
  end

  def test_illegal_bracketexpr_range
    assert_raise ToknInternal::ParseException do
      tok =<<-'eos'
        C: [b-a]
      eos
      script = "abcde"
      verify(tok,script,nil)
    end
  end

  def test_bracketexpr_escaped_chars
    tok =<<-'eos'
      C: [a\nc-df]
    eos
    script = "abc\ndefg"
    verify(tok,script,nil)
  end

  def test_bracketexpr_negated_escaped_chars
    tok =<<-'eos'
      C: [^\nb]
    eos
    script = "abc\ndefg"
    verify(tok,script,nil)
  end

  # Extract tokens from script
  #
  def verify(tokens_defn_string,script,skip_token_name='WS')
    # return if @allow.nil?
    dfa = Tokn::DFA.from_script(tokens_defn_string)
    if false
      dotfile = dfa.startState.build_dot_file("dfa")
      path = "_t.dot"
      warning "writing dot file to #{path}"
      FileUtils.write_text_file(path,dotfile)
    end

    TestSnapshot.new.perform do

      tok = Tokn::Tokenizer.new(dfa, script, skip_token_name)

      tok.accept_unknown_tokens = true

      while tok.has_next
        t = tok.read
        puts "%-9s '%s'" % [dfa.token_name(t.id), t.text]
      end
    end
  end

  # Determine path to a file relative to this files's directory
  #
  def path_to_resources(file)
    File.join(File.dirname(File.expand_path(__FILE__)), file)
  end

  def test_string_expr
    tok =<<-'eos'
    STRING: ( " ([^\n"] | (\\") )* " | ' ([^\n']|(\\'))* ' )
    eos
    script = FileUtils.read_text_file(path_to_resources('_string_expr.txt')).strip!
    verify(tok,script,nil)
  end

end

