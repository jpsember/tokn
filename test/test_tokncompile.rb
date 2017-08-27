require "js_test"

class TestToknCompile < JSTest

  def test_ToknCompile
    TestSnapshot.new.perform do
      SysCall.new("ruby bin/tokncompile < test/sampletokens.txt").hide_command.call
    end
  end

  def sampleTokens
    dir = File.dirname(__FILE__)
    @sampleTokens ||= File.read("#{dir}/sampletokens.txt")
  end

end
