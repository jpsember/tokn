require 'js_base/js_test'
require 'tokn'

class TestFilter < JSTest

  def test_generated_edge_count
    dfa = Tokn::DFA.from_script(TOKEN_SCRIPT)

    states,_,_ = dfa.startState.reachableStates
    total_edges = 0
    states.each do |state|
      total_edges += state.edges.size
    end

    assert_equal(11, total_edges)
  end

  def test_Filter
    dfa = Tokn::DFA.from_script(TOKEN_SCRIPT)

    text = "abcabcdef"
    tok = Tokn::Tokenizer.new(dfa, text)

    tok.read("SPECIFIC")
    tok.read("SPECIFIC")
    tok.read("GENERAL")

    assert(!tok.has_next)
  end

  TOKEN_SCRIPT =<<-'END'

GENERAL: [a-z]+
SPECIFIC: abc

END

end
