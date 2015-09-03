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

  def test_continue_line_with_backslash
    # There are no characters between the backslash and the linefeed; this will be interpreted
    # as a 'line stitch' command
    script = "A: ab\\\nab"
    dfa = Tokn::DFA.from_script(script)
    tok = Tokn::Tokenizer.new(dfa,"abababababab")
    tok.read
    tok.read
    tok.read
    assert(!tok.has_next)
  end

  def test_continue_line_with_backslash_not_at_end
    # Note there's a space between the backslash and the linefeed; this will be interpreted
    # as an escaped space, not as a 'line stitch' command
    script = "A: ab\\ \nB: ab"
    dfa = Tokn::DFA.from_script(script)
    tok = Tokn::Tokenizer.new(dfa,"abab ab")
    tok.read(1)
    tok.read(0)
    tok.read(1)
    assert(!tok.has_next)
  end

  def test_continue_line_with_multiple_backslash
    script = "A: ab\\\\\\\\\\\nab\nB: ab"
    dfa = Tokn::DFA.from_script(script)
    tok = Tokn::Tokenizer.new(dfa,"abab\\\\abab")
    tok.read(1)
    tok.read(0)
    tok.read(1)
    assert(!tok.has_next)
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

  def test_comment_problem
    script = ""
    script << 'WS: (   [\\x00-\\x20]+ | \\# [\\x00-\\x09\\x0b-\\x7f]* \\n? )'
    script << "\n"
    script << 'ID: \\d+'
    script << "\n"

    dfa = Tokn::DFA.from_script(script)
    tok = Tokn::Tokenizer.new(dfa,"   14  \n   # white space 42 \n  19 83  ")
    [0,1,0,0,0,1,0,1,0].each do |id|
      tok.read(id)
    end
    assert !tok.has_next
  end

  def test_bracket_expr_disallowed
    script = ""
    script << 'WS: (   [\\x00-\\x20^\\n]+ )'

    assert_raise ToknInternal::ParseException do
      Tokn::DFA.from_script(script)
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
