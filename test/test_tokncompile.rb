require 'js_base/js_test'
# require 'js_base/file_utils'

class TestToknCompile < JSTest

  def test_ToknCompile
    if true
      puts "skipping test"
      return
    end
    begin
      TestSnapshot.new.perform do
        output,_ = scall("ruby bin/tokncompile < test/sampletokens.txt")
        puts output
      end
    rescue Exception => e
      raise "*** there was a problem with the test... perhaps try makegem . first?  See Issue #18."
    end
  end

  def sampleTokens
    dir = File.dirname(__FILE__)
    @sampleTokens ||= FileUtils.read_text_file("#{dir}/sampletokens.txt")
  end

  def test_Persist
    script = sampleTokens
    require 'digest/sha1'
    persist_dir = File.join(Dir.home,'.compiled_dfa')
    persist_path = File.join(persist_dir,Digest::SHA1.hexdigest(script))
    FileUtils.rm(persist_path) if File.exist?(persist_path)
    assert(!File.exist?(persist_path))
    Tokn::DFA.from_script(sampleTokens)
    assert(File.exist?(persist_path))
  end

end
