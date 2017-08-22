#!/usr/bin/env ruby

require 'js_base/js_test'
require 'tokn'

class TestFilter < JSTest

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
    dfa.startState.generate_pdf("_SKIP_dfa.pdf")
    dfa
  end

  def build_tokenizer_from_script
    Tokn::Tokenizer.new(build_dfa_from_script, sampleText)
  end

  def test_Filter
    tok = build_tokenizer_from_script
    tok.read("X")
    tok.read("X")
    tok.read("WS")
    assert(!tok.has_next)
  end

end
