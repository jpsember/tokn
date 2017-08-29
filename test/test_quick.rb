require "js_test"
require "tokn/compiler"

class TestQuick < JSTest

  include ToknInternal

  def test_future
    script =<<-'EOT'
MISC: \d+
ALPHA: abcdef
BETA: abc
EOT

    begin
      Tokn::DFACompiler.from_script(script)
      raise "expected exception"
    rescue ToknInternal::ParseException => e
      assert e.message.include?("Redundant token")
    end

  end

end
