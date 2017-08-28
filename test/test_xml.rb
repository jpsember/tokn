require "js_test"
require "tokn/compiler"

class TestXML < JSTest

  include ToknInternal

  def setup
    enter_test_directory
  end

  def teardown
    leave_test_directory
  end

  # Extract tokens from script
  #
  def verify(tokens_defn_string, script)
    dfa = Tokn::DFACompiler.from_script(tokens_defn_string)

    TestSnapshot.new.perform do

      tok = Tokn::Tokenizer.new(dfa, script)

      tok.accept_unknown_tokens = true

      while tok.has_next
        t = tok.read
        puts "%-9s '%s'" % [dfa.token_name(t.id), t.text]
      end
    end
  end

  def test_xml_parser
    parser = ToknInternal::TokenDefParser.new
    parser.parse(File.read("../xmltokens.txt"))
    script = File.read("../xmlscript.txt")
    verify(tok,script)
  end

end
