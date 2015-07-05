require 'js_base/js_test'
# require 'js_base/file_utils'

class TestToknCompile < JSTest

  def test_ToknCompile
    TestSnapshot.new.perform do
      output,_ = scall("ruby -I./lib bin/tokncompile < test/sampletokens.txt")
      puts output
      # Write dfa for use by toknprocess test
      # FileUtils.write_text_file("test/compileddfa.txt",output,true)
    end
  end

end
