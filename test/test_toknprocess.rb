require 'js_base/js_test'

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
      output,_ = scall("ruby ../../bin/toknprocess #{dfa_path} ../sampletext.txt")
      puts output
    end
  end

end
