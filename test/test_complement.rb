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
    Tokn::Tokenizer.new(build_dfa_from_script, sampleText, 'WS')
  end

  def test_Complement
    tok = build_tokenizer_from_script

    while tok.has_next
      t = tok.read
      puts "#{tok.name_of(t)}: '#{t.text}'"
    end

  end

end