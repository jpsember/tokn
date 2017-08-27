require 'js_base/js_test'
require 'tokn'

class TestTopSort < JSTest

  include ToknInternal

  def setup
    enter_test_directory
    @sampleText = nil
    @sampleTokens = nil
  end

  def teardown
    leave_test_directory
  end

  def sampleText
    @sampleText ||= <<'EOS'
'escaped \' delimiter'
EOS
  end

  def sampleTokens
    @sampleTokens ||= <<'EOS'
WS:   ( [\s\n]+ )
LBL: '([^'\n]|\\')*'


# This disallows unescaped backslashes, and is what we want,
# but the unit tests pass
#
#LBL: '   (  [^'\\\n] |  (\\')  )*    '
EOS
  end

  def build_dfa_from_script
    dfa = Tokn::DFACompiler.from_script(sampleTokens)
    dfa
  end

  def build_tokenizer_from_script
    Tokn::Tokenizer.new(build_dfa_from_script, sampleText)
  end

  def test_TopSort
    dfa = build_dfa_from_script
    state = dfa.start_state

    sorted_states = state.topological_sort
    str = ""
    sorted_states.each do |s|
      str << " " << "#{s.id}"
    end
    str.strip!

    assert_equal("0 2 1 5 6 4 3", str)
  end

end
