require 'js_base'

require_relative 'dfa'

dfa = Tokn::DFA.from_script(ARGF.read)
puts "...generating pdf"
dfa.startState.generate_pdf("_SKIP_experiment.pdf")

