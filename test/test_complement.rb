#!/usr/bin/env ruby

require 'js_base/js_test'
require 'tokn'

class TestComplement < JSTest

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
    @sampleText ||= FileUtils.read_text_file("../complement_text.txt")
  end

  def sampleTokens
    @sampleTokens ||= FileUtils.read_text_file("../complement_tokens.txt")
  end

  def build_dfa_from_script
    dfa = Tokn::DFA.from_script(sampleTokens)
    dfa
  end

  def build_tokenizer_from_script
    Tokn::Tokenizer.new(build_dfa_from_script, sampleText)
  end

  def test_Tokenizer

    tok = build_tokenizer_from_script

    tokList = []
    while tok.has_next
      t = tok.read
      tokList.push(t)
    end

    tok.unread(tokList.size)

    tokList.each do |t1|
      tName = tok.name_of(t1)
      tok.read(tName)
    end
  end

end
