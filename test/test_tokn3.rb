#!/usr/bin/env ruby

require 'js_base/js_test'
require 'tokn'

class TestTokn3 < JSTest

  include ToknInternal

  def setup
    enter_test_directory
    @sampleText = FileUtils.read_text_file("../sampletext3.txt").chomp!
    @sampleTokens = FileUtils.read_text_file("../sampletokens3.txt")
  end

  def teardown
    leave_test_directory(true)
  end

  def build_dfa_from_script
    @dfa = Tokn::DFA.from_script(@sampleTokens)
    if false
      warning "building DFA"
      s_dfa = DFABuilder.nfa_to_dfa(@dfa.startState)
      FileUtils.write_text_file("../../mydfa.dot",s_dfa.build_dot_file("dfa"))
    end
    @dfa
  end

  def build_tokenizer_from_script
    Tokn::Tokenizer.new(build_dfa_from_script, @sampleText)
  end

  def test_Tokenizer
    TestSnapshot.new.perform do

      tok = build_tokenizer_from_script

      tok.accept_unknown_tokens = true

      while tok.has_next
        t = tok.read
        puts " read #{t.id}: '#{t.text}'"
      end
    end
  end

end
