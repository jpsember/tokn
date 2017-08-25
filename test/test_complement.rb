#!/usr/bin/env ruby

require 'js_base/js_test'
require 'tokn'

class TestComplement < JSTest

  @@dfa = nil

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
    @sampleText ||= <<-'END'
xyz abc 123abcdef 789ab012
END

  end

  def sampleTokens
    @sampleTokens ||= <<-'END'

WS: (\n | \r | \t | \s)+
_TX: [^\n\r\t\s]+
_KEYWORD: abc
NONSPECIAL: ^($TX $KEYWORD $TX) $WS
SPECIAL: $TX $KEYWORD $TX $WS

END
  end

  def build_dfa_from_script
    if @@dfa.nil?
      dfa = Tokn::DFA.from_script(sampleTokens)
      @@dfa = dfa
    end
    @@dfa
  end

  def build_tokenizer_from_script
    Tokn::Tokenizer.new(build_dfa_from_script, sampleText)
  end

  def test_Complement
    TestSnapshot.new.perform do
      tok = build_tokenizer_from_script
      tok.accept_unknown_tokens = true

      while tok.has_next
        t = tok.read
        puts "#{tok.name_of(t)}: '#{t.text}'"
      end
    end
  end

end
