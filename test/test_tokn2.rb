require 'js_base/js_test'
require 'tokn'

class TestTokn2 < JSTest

  def teardown
    leave_test_directory(true)
  end

  def build_tokenizer_from_script
    @dfa = Tokn::DFA.from_script(@sampleTokens)
    Tokn::Tokenizer.new(@dfa, @sampleText)
  end

  def test_Tokenizer
    TestSnapshot.new.perform do

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

  def setup
    enter_test_directory
    @sampleText =<<-'eos'
the time has come 42
the Walrus said


eos

    @sampleTokens =<<-'eos'
UNKNOWN: [\u0000-\uffff]
WS: [\f\r\s\t\n]+
WORD: [a-zA-Z]+('[a-zA-Z]+)*
eos

  end


end
