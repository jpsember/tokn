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


  # Extract tokens from script
  #
  def verify(tokens_defn_string,script,skip_token_name='WS')
    dfa = Tokn::DFA.from_script(tokens_defn_string)

    TestSnapshot.new.perform do

      tok = Tokn::Tokenizer.new(dfa, script, skip_token_name)

      tok.accept_unknown_tokens = true

      while tok.has_next
        t = tok.read
        puts "%-9s '%s'" % [dfa.token_name(t.id), t.text]
      end
    end
  end

end
