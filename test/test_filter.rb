require "js_test"
require "tokn/compiler"

class TestFilter < JSTest

  def test_generated_edge_count
    dfa = Tokn::DFACompiler.from_script(TOKEN_SCRIPT)

    states = dfa.start_state.reachable_states
    total_edges = 0
    states.each do |state|
      total_edges += state.edges.size
    end

    assert_equal(14, total_edges)
  end

  def test_Filter
    if false
      dfa = Tokn::DFACompiler.from_script_with_pdf(TOKEN_SCRIPT)
    else
      dfa = Tokn::DFACompiler.from_script(TOKEN_SCRIPT)
    end

    text = "abc abcdef def"
    tok = Tokn::Tokenizer.new(dfa, text)

    tok.read("SPECIFIC")
    tok.read("WS")
    tok.read("GENERAL")
    tok.read("WS")
    tok.read("GENERAL")

    assert(!tok.has_next)
  end

  TOKEN_SCRIPT =<<-'END'

WS: \0x20
GENERAL: [a-z]+
SPECIFIC: abc

END

end
