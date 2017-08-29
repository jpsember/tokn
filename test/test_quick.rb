require "js_test"
require "tokn/compiler"

class TestQuick < JSTest

  include ToknInternal

  def test_future
    script =<<-'EOT'
MISC: \d+
ALPHA: abc
BETA: abcdef
EOT

    begin
      Tokn::DFACompiler.from_script(script)
      raise "expected exception"
    rescue ToknInternal::ParseException => e
      assert e.message.include?("Redundant token")
      assert e.message.include?("line 2;")
    end

  end

end
