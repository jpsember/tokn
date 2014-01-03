#!/usr/bin/env ruby

require 'js_base/test'
require 'tokn'

class TestTokn <  Test::Unit::TestCase

  include ToknInternal

  def setup
    enter_test_directory
    @sampleText = FileUtils.read_text_file("../sampletext.txt")
    @sampleTokens = FileUtils.read_text_file("../sampletokens.txt")
  end

  def teardown
    leave_test_directory
  end

  REGEX_SCRIPT = "(\\-?[0-9]+)|[_a-zA-Z][_a-zA-Z0-9]*|333q"

  TOKEN_SCRIPT2 = <<'END'
        sep:  \s
        tku:  a(a|b)*
        tkv:  b(aa|b*)
        tkw:  bbb
END

  def build_dfa_from_script
    Tokn::DFA.from_script(@sampleTokens)
  end

  def build_tokenizer_from_dfa
    FileUtils.write_text_file("_dfa_.txt", build_dfa_from_script.serialize())
    dfa = Tokn::DFA.from_file("_dfa_.txt")
    Tokn::Tokenizer.new(dfa, @sampleText)
  end

  def build_tokenizer_from_script
    Tokn::Tokenizer.new(build_dfa_from_script, @sampleText)
  end

  def test_CompileDFA
    build_tokenizer_from_dfa
  end

  def test_build_DFA
    x =  RegParse.new(REGEX_SCRIPT)
    s = x.startState
    x.endState.finalState = true
    s.reverseNFA()
    s_dfa = DFABuilder.nfa_to_dfa(s)
    IORecorder.new.perform do
      puts s_dfa.build_dot_file("dfa")
    end
  end

  def test_cvt_NFA_to_DFA
    x = RegParse.new(REGEX_SCRIPT)
    s = x.startState
    x.endState.finalState = true
    IORecorder.new.perform do
      puts s.build_dot_file("nfa")
    end
    dfa = DFABuilder.nfa_to_dfa(s)

    oldToNewMap, _ = dfa.duplicateNFA(42)
    oldToNewMap[dfa]
  end

  def test_TokenDefParser
    TokenDefParser.new(TOKEN_SCRIPT2)
  end

  def test_Tokenizer

    tok = build_tokenizer_from_script

    tokList = []
    while tok.hasNext
      t = tok.read
      tokList.push(t)
    end

    tok.unread(tokList.size)

    tokList.each do |t1|
      tName = tok.nameOf(t1)
      tok.read(tName)
    end
  end

  def test_Tokenizer_Missing_Expected

    assert_raise Tokn::TokenizerException do

      tok = build_tokenizer_from_script

      tok.read
      tok.read
      tok.read
      tok.read
      tok.read("signedint")
    end

  end

  def test_readAndUnread
    tok = build_tokenizer_from_dfa
    unread = false
    while tok.hasNext
      t = tok.read
      if !unread && tok.nameOf(t) == "DO"
        tok.unread(4)
        unread = true
      end
    end
  end

  def test_UnrecognizedToken
    assert_raise Tokn::TokenizerException do
      tok = build_tokenizer_from_dfa
      while tok.hasNext
        t = tok.read
        if tok.nameOf(t) == "DO"
          tok.read("BRCL") # <== this should raise problem
        end
      end
    end
  end

  def test_ReadPastEnd
    assert_raise Tokn::TokenizerException do
      tok = build_tokenizer_from_dfa
      while tok.hasNext
        tok.read
      end
      tok.read
    end
  end

  def test_UnreadBeforeStart

    assert_raise Tokn::TokenizerException do
      tok = build_tokenizer_from_dfa
      k = 0
      while tok.hasNext
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

  def test_filter_ws
    IORecorder.new.perform do
      dfa = Tokn::DFA.from_script_file("../sampletokens.txt")
      t = Tokn::Tokenizer.new(dfa, FileUtils.read_text_file("../sampletext.txt"), "WS")

      while t.hasNext do
        tk = t.peek
        if t.nameOf(tk) == 'BROP'
          lst = t.readSequenceIf('BROP DO ID BRCL')
          if lst
            puts " ...read BROP DO ID sequence..."
            lst.each{ |x| puts "   #{x}"}
            next
          else
            puts " ...couldn't find sequence..."
          end
        end

        tk = t.read
        puts tk
      end
    end
  end

end
