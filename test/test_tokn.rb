#!/usr/bin/env ruby

require 'js_base/js_test'
require 'tokn'

class TestTokn < JSTest

  include ToknInternal

  def setup
    enter_test_directory
  end

  def teardown
    leave_test_directory
  end

  def sampleText
    @sampleText ||= FileUtils.read_text_file("../sampletext.txt")
  end

  def sampleTokens
    @sampleTokens ||= FileUtils.read_text_file("../sampletokens.txt")
  end

  REGEX_SCRIPT = "(\\-?[0-9]+)|[_a-zA-Z][_a-zA-Z0-9]*|333q"

  TOKEN_SCRIPT2 = <<'END'
        sep:  \s
        tku:  a(a|b)*
        tkv:  b(aa|b*)
        tkw:  bbb
END

  def build_dfa_from_script
    Tokn::DFA.from_script(sampleTokens)
  end

  def build_tokenizer_from_script
    Tokn::Tokenizer.new(build_dfa_from_script, sampleText)
  end

  def test_CompileDFA
    build_tokenizer_from_script
  end

  def test_build_DFA
    x = RegParse.new(REGEX_SCRIPT)
    s = x.startState
    x.endState.finalState = true
    s.reverseNFA()
    builder = DFABuilder.new(s)
    builder.with_filter = false
    s_dfa = builder.nfa_to_dfa
    TestSnapshot.new.perform do
      puts s_dfa.build_dot_file("dfa")
    end
  end

  def test_cvt_NFA_to_DFA
    x = RegParse.new(REGEX_SCRIPT)
    s = x.startState
    x.endState.finalState = true
    TestSnapshot.new.perform do
      puts s.build_dot_file("nfa")
    end

    builder = DFABuilder.new(s)
    builder.with_filter = false
    dfa = builder.nfa_to_dfa

    oldToNewMap, _ = dfa.duplicateNFA(42)
    oldToNewMap[dfa]
  end

  def test_TokenDefParser
    TokenDefParser.new(TOKEN_SCRIPT2)
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

  def test_Tokenizer_Missing_Expected

    assert_raises Tokn::TokenizerException do

      tok = build_tokenizer_from_script

      tok.read
      tok.read
      tok.read
      tok.read
      tok.read("signedint")
    end

  end

  def test_readAndUnread
    tok = build_tokenizer_from_script
    unread = false
    while tok.has_next
      t = tok.read
      if !unread && tok.name_of(t) == "DO"
        tok.unread(4)
        unread = true
      end
    end
  end

  def test_UnrecognizedToken
    assert_raises Tokn::TokenizerException do
      tok = build_tokenizer_from_script
      while tok.has_next
        t = tok.read
        if tok.name_of(t) == "DO"
          tok.read("BRCL") # <== this should raise problem
        end
      end
    end
  end

  def test_ReadPastEnd
    assert_raises Tokn::TokenizerException do
      tok = build_tokenizer_from_script
      while tok.has_next
        tok.read
      end
      tok.read
    end
  end

  def test_UnreadBeforeStart

    assert_raises Tokn::TokenizerException do
      tok = build_tokenizer_from_script
      k = 0
      while tok.has_next
        tok.read
        k += 1
        if k == 15
          tok.unread(5)
          tok.unread(7)
          tok.read()
          tok.unread(4)
          tok.unread(3)
        end
      end
      tok.read
    end
  end

  def report_seq(lst)
    if lst
      puts
      puts "                 FOUND"
      puts
      lst.each{ |x| puts "   #{x}"}
      true
    else
      puts " ...not found"
      false
    end
  end

  def test_read_named_sequence
    TestSnapshot.new.perform do
      dfa = Tokn::DFA.from_script(sampleTokens)
      t = Tokn::Tokenizer.new(dfa, sampleText, "WS")

      while t.has_next do
        tk = t.peek
        if t.name_of(tk) == 'BROP'
          lst = t.read_sequence_if('BROP DO ID BRCL')
          next if report_seq(lst)
        end
        tk = t.read
        puts tk
      end
    end
  end

  def test_read_named_sequence_unconditionally
    TestSnapshot.new.perform do
      dfa = Tokn::DFA.from_script(sampleTokens)
      t = Tokn::Tokenizer.new(dfa, sampleText, "WS")

      while t.has_next do
        tk = t.read
        if tk.text == 'speed'
          tokens = t.read_sequence('ASSIGN INT ID')
          report_seq(tokens)
        end
      end
    end
  end

  def test_read_named_sequence_unconditionally_fails
    assert_raises Tokn::TokenizerException do
      dfa = Tokn::DFA.from_script(sampleTokens)
      t = Tokn::Tokenizer.new(dfa, sampleText, "WS")

      while t.has_next do
        tk = t.read
        if tk.text == 'speed'
          t.read_sequence('ASSIGN INT INT')
        end
      end
    end
  end

  def test_read_id_sequence_unconditionally
    TestSnapshot.new.perform do
      dfa = Tokn::DFA.from_script(sampleTokens)
      t = Tokn::Tokenizer.new(dfa, sampleText, "WS")

      while t.has_next do
        tk = t.read
        if tk.text == 'speed'
          tokens = t.read_sequence([5,1,4])
          report_seq(tokens)
        end
      end
    end
  end

  def test_read_id_sequence_unconditionally_fails
    assert_raises Tokn::TokenizerException do
      dfa = Tokn::DFA.from_script(sampleTokens)
      t = Tokn::Tokenizer.new(dfa, sampleText, "WS")

      while t.has_next do
        tk = t.read
        if tk.text == 'speed'
          t.read_sequence([5,2,2])
        end
      end
    end
  end


  def test_read_id_sequence
    TestSnapshot.new.perform do
      dfa = Tokn::DFA.from_script(sampleTokens)
      t = Tokn::Tokenizer.new(dfa, sampleText, "WS")

      while t.has_next do
        tk = t.peek
        # puts "token #{tk} id=#{tk.id}"
        if tk.id == 4
          lst = t.read_sequence_if([4,5,3])
          next if report_seq(lst)
        end

        tk = t.read
        puts tk
      end
    end
  end

  def test_read_named_sequence_with_wildcards
    TestSnapshot.new.perform do
      dfa = Tokn::DFA.from_script(sampleTokens)
      t = Tokn::Tokenizer.new(dfa, sampleText, "WS")

      while t.has_next do
        tk = t.peek
        if t.name_of(tk) == 'ID'
          lst = t.read_sequence_if('ID ASSIGN _')
          next if report_seq(lst)
        end

        tk = t.read
        puts "#{tk} id=#{tk.id}"
      end
    end
  end

  def test_read_id_sequence_with_wildcards
    TestSnapshot.new.perform do
      dfa = Tokn::DFA.from_script(sampleTokens)
      t = Tokn::Tokenizer.new(dfa, sampleText, "WS")

      while t.has_next do
        tk = t.peek
        if tk.id == 4
          lst = t.read_sequence_if([4,5,nil])
          next if report_seq(lst)
        end

        tk = t.read
        puts tk
      end
    end
  end

  def test_c_style_comments
    TestSnapshot.new.perform do
      dfa = Tokn::DFA.from_script(sampleTokens)
      text = SAMPLETEXT2
      t = Tokn::Tokenizer.new(dfa, text)

      while t.has_next do
        tk = t.read
        puts tk
      end
    end
  end

  def build_file
    f = File.new('diskfile.txt','w')
    1000.times{f.write("aa baa bbb ")}
    f.close
  end

  def test_read_from_file
    build_file
    dfa = Tokn::DFA.from_script(TOKEN_SCRIPT2)
    t = Tokn::Tokenizer.new(dfa,File.open('diskfile.txt','r'),'sep',50)
    1000.times do
      t.read('tku')
      t.read('tkv')
      t.read('tkw')
    end
    assert(t.peek() == nil,"expected end of tokens")
  end

  def test_unread_from_file_legal
    build_file
    dfa = Tokn::DFA.from_script(TOKEN_SCRIPT2)
    history_size = 8
    total_tokens = 3000

    t = Tokn::Tokenizer.new(dfa,File.open('diskfile.txt','r'),'sep',history_size)
    500.times{t.read}
    t.unread(history_size)
    (total_tokens-500+history_size).times{t.read}
  end

  def test_unread_from_file_illegal
    build_file
    dfa = Tokn::DFA.from_script(TOKEN_SCRIPT2)
    history_size = 8
    t = Tokn::Tokenizer.new(dfa,File.open('diskfile.txt','r'),'sep',history_size)
    500.times{t.read}
    e = assert_raises Tokn::TokenizerException do
        # Include an amount greater than the slack
        t.unread(history_size+110)
    assert(e.message.start_with?('Token unavailable'))
    end
  end

  def test_read_if_name
    tok = build_tokenizer_from_script
    assert(tok.read_if('WS') != nil)
  end

  def test_read_if_id
    tok = build_tokenizer_from_script
    assert(tok.read_if(0) != nil)
  end

  def test_unknown
    dfa = Tokn::DFA.from_script(TOKEN_SCRIPT2)
    t = Tokn::Tokenizer.new(dfa,'ddd')
    e = assert_raises Tokn::TokenizerException do
      t.read
    end
    assert(e.message.start_with?('Unknown token'))
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
    script = "A: aa\\ \nB: ab"
    dfa = Tokn::DFA.from_script(script)
    tok = Tokn::Tokenizer.new(dfa,"abaa ab")
    tok.read(1)
    tok.read(0)
    tok.read(1)
    assert(!tok.has_next)
  end

  def test_continue_line_with_multiple_backslash
    script = "A: ab\\\\\\\\\\\nab\nB: bb"
    dfa = Tokn::DFA.from_script(script)
    tok = Tokn::Tokenizer.new(dfa,"bbab\\\\abbb")
    tok.read(1)
    tok.read(0)
    tok.read(1)
    assert(!tok.has_next)
  end

  def test_Tokenizer
    TestSnapshot.new.perform do

      dfa = Tokn::DFA.from_script(SAMPLETOKENS3)
      tok = Tokn::Tokenizer.new(dfa, SAMPLETEXT3)

      tokList = []
      while tok.has_next
        t = tok.read
        tokList.push(t)
        puts " read: #{dfa.token_name(t.id)} '#{t}'"
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

  def test_altern_problem
    script = ""
    script << 'WS: (   [\\x00-\\x20]+ | \\# [\\x00-\\x09\\x0b-\\x7f]* \\n? )'
    script << "\n"
    script << 'TAGEND:   (  (/ [a-zA-Z]*) | \? )? >'
    script << "\n"

    dfa = Tokn::DFA.from_script(script)
    tok = Tokn::Tokenizer.new(dfa,"/abc>  >  ?>  ")
    [1,0,1,0,1,0].each do |id|
      tok.read(id)
    end
    assert !tok.has_next
  end

  # We put this at the end because the heredoc confuses Sublime editor

  SAMPLETEXT2 =<<-'EOS'
// c-style comments:

/**/
a
/***/
b
/****/
c
/*
x
*/
/* x   /* x */
d
/*    /*/
e
EOS

    SAMPLETEXT3 =<<-'EOS'
the time has come 42
the Walrus said
EOS

    SAMPLETOKENS3 =<<-'EOS'
UNKNOWN: [\u0000-\uffff]
WS: ( [\f\r\s\t\n]+ | \
       \#[^\n]*\n? )
WORD: [a-zA-Z]+('[a-zA-Z]+)*
EOS

end
