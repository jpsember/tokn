require 'js_base/js_test'
require 'tokn'

class TestTokn3 < JSTest

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
    @sampleText =<<-'EOS'
the time has come 42
the Walrus said
EOS

    @sampleTokens =<<-'EOS'
UNKNOWN: [\u0000-\uffff]
WS: ( [\f\r\s\t\n]+ | \
       \#[^\n]*\n? )
WORD: [a-zA-Z]+('[a-zA-Z]+)*
EOS

  end


end
