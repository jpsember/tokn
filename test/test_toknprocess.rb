require 'js_base/js_test'

class TestToknProcess < JSTest

  def test_ToknProcess
    TestSnapshot.new.perform do
      output,_ = scall("ruby bin/toknprocess test/compileddfa.txt test/sampletext.txt")
      puts output
    end
  end

end
