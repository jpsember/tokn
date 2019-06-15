require "js_test"
require "tokn/compiler"

class TestPriority < JSTest

  def test_Priority
    dfa = Tokn::DFACompiler.from_script(TOKEN_SCRIPT)
    text = "runabc abcrun run abc"
    s = parse(dfa,text)
    TestSnapshot.new.perform do
      puts s
    end
  end

  TOKEN_SCRIPT =<<-'SCR'
    WS: \0x20+
    IDENTIFIER: [a-z]+
    COMMAND: run
SCR

  def test_Priority2
    dfa = Tokn::DFACompiler.from_script(TOKEN_SCRIPT2)
    text = "abc abd"

    s = parse(dfa,text)
    TestSnapshot.new.perform do
      puts s
    end
  end

  TOKEN_SCRIPT2 =<<-'SCR'
    WS: \0x20+
    GENERAL: ab[a-z]
    SPECIFIC: abc
SCR

  def parse(dfa, text)

    s = "\n"
    j = dfa.to_json
    s << "Total states: #{j["states"].size}\n"
    s << "\n"

    tok = Tokn::Tokenizer.new(dfa, text)

    s << "Text: '" << text << "'\n"
    s << "\nParsed:\n\n"

    while tok.has_next
      t = tok.read
      s << sprintf("%-12s: %s\n",tok.name_of(t),t.text)
    end
    s << "\n"
    s
  end

end
