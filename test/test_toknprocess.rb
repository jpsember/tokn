require 'js_base/js_test'

class TestToknProcess < JSTest

  def test_ToknProcess
    begin
      TestSnapshot.new.perform do
        output,_ = scall("ruby bin/toknprocess test/compileddfa.txt test/sampletext.txt")
        puts output
      end
    rescue Exception => e
      raise "*** there was a problem with the test... perhaps try makegem . first?  See Issue #18."
    end
  end

end
