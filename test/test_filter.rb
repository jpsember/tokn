require 'js_base/js_test'
require 'tokn'

class TestFilter < JSTest

  def build_dfa_from_script
    dfa = Tokn::DFA.from_script(TOKEN_SCRIPT)
    #dfa.startState.generate_pdf("_SKIP_dfa.pdf")
    dfa
  end

  def build_tokenizer_from_script
    Tokn::Tokenizer.new(build_dfa_from_script, TOKEN_TEXT, "WS")
  end

  def test_Filter
    tok = build_tokenizer_from_script

    tok.read("MISC")
    tok.read("MISC")
    tok.read("SPECIFIC")
    tok.read("MISC")

    assert(!tok.has_next)
  end

  TOKEN_SCRIPT =<<-'END'
WS:   ( [\s\n]+ )
MISC: [a-z]+
SPECIFIC: foo
END

  TOKEN_TEXT =<<-'END'
abc abcfoodef foo ghi
END

end
