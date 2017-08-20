require 'js_base'

require_relative 'dfa'
require_relative 'tokenizer'
require_relative 'token'
require_relative 'tokenizer_exception'

text = FileUtils.read_text_file("test/exptext.txt")
puts "Tokenizing:"
puts text
puts

dfa = Tokn::DFA.from_script(ARGF.read)
dfa.startState.generate_pdf("_SKIP_experiment.pdf")

skipName = 'WS'

tk =  Tokn::Tokenizer.new(dfa, text, skipName)

while tk.has_next
  t = tk.read
  printf("%s %d %d %s\n",tk.name_of(t),t.lineNumber,t.column,t.text)
end

