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

  def test_Persist
    script = sampleTokens
    require 'digest/sha1'
    persist_dir = File.join(Dir.home,".compiled_dfa_#{Tokn::DFA.version}")
    persist_path = File.join(persist_dir,Digest::SHA1.hexdigest(script))
    FileUtils.rm(persist_path) if File.exist?(persist_path)
    assert(!File.exist?(persist_path))
    Tokn::DFA.from_script(sampleTokens)
    assert(File.exist?(persist_path))
  end

end
