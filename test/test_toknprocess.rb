require "js_test"

class TestToknProcess < JSTest

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
      SysCall.new("toknprocess #{dfa_path} ../sampletext.txt").hide_command.call
    end
  end

end
