require 'js_base/js_test'

class TestToknCompile < JSTest

  def test_ToknCompile
    TestSnapshot.new.perform do
      output,_ = scall("ruby bin/tokncompile < test/sampletokens.txt")
      puts output
    end
  end

  def sampleTokens
    dir = File.dirname(__FILE__)
    @sampleTokens ||= FileUtils.read_text_file("#{dir}/sampletokens.txt")
  end

end
