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
    @sampleText ||= FileUtils.read_text_file("../sampletext3.txt")
  end

  def sampleTokens
    @sampleTokens ||= FileUtils.read_text_file("../sampletokens3.txt")
  end

  def build_dfa_from_script
    dfa = Tokn::DFA.from_script(sampleTokens)
    dfa
  end

  def build_tokenizer_from_script
    Tokn::Tokenizer.new(build_dfa_from_script, sampleText)
  end

  def test_TopSort
    dfa = build_dfa_from_script
    state = dfa.startState

    sorted_states = state.topological_sort
    str = ""
    sorted_states.each do |s|
      str << " " << "#{s.id}"
    end
    str.strip!

    assert_equal("0 2 1 5 6 4 3", str)
  end

end
