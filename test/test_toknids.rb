require "js_test"
require "tokn/compiler"

class TestToknIds < JSTest

  def setup
    enter_test_directory
  end

  def teardown
    leave_test_directory
  end

  def test_ToknProcess

    dfa_path = "compileddfa.txt"

    # Generate compiled dfa from tokens
    system("tokncompile < ../sampletokens.txt > #{dfa_path}")

    TestSnapshot.new.perform do
      SysCall.new("toknids #{dfa_path}").hide_command.call
    end
  end

end
