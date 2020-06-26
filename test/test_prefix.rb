require "js_test"
require "tokn/compiler"

class TestPrefix < JSTest

  def test_compile
    TestSnapshot.new.perform do
      SysCall.new("ruby bin/tokncompile < #{resource_dir}/token_def.txt").hide_command.call
    end
  end

  def test_parse
    TestSnapshot.new.perform do
      SysCall.new("ruby bin/toknprocess #{tokn_defs_file} #{resource_dir}/sample_text.txt").hide_command.call
    end
  end

  def resource_dir
    @resource_dir ||=  "#{File.dirname(__FILE__)}/prefix"
  end

  def tokn_defs_file
    @tokn_defs_file ||= "#{resource_dir}/token_def.json"
  end

end
