#!/usr/bin/env ruby

require 'js_base/test'
require 'tokn'

class TestTokn2 <  Test::Unit::TestCase

  include ToknInternal

  def setup
    enter_test_directory
    @sampleText = FileUtils.read_text_file("../sampletext2.txt")
    @sampleTokens = FileUtils.read_text_file("../sampletokens2.txt")
  end

  def teardown
    leave_test_directory(true)
  end

  def build_dfa_from_script
    @dfa = Tokn::DFA.from_script(@sampleTokens)
  end

  def build_tokenizer_from_script
    Tokn::Tokenizer.new(build_dfa_from_script, @sampleText)
  end

  def test_CompileDFA
    FileUtils.write_text_file("_dfa_.txt", build_dfa_from_script.serialize())
    dfa = Tokn::DFA.from_file("_dfa_.txt")
    Tokn::Tokenizer.new(dfa, @sampleText)
  end

  def test_Tokenizer
    IORecorder.new.perform do

      tok = build_tokenizer_from_script

      tokList = []
      while tok.has_next
        t = tok.read
        tokList.push(t)
        puts " read: #{@dfa.token_name(t.id)} '#{t}'"
      end

      tok.unread(tokList.size)

      tokList.each do |t1|
        tName = tok.name_of(t1)
        tok.read(tName)
      end
    end
  end

end
