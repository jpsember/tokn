module Tokn

  # Support for compiling and serializing DFAs
  #
  class DFACompiler

    # TODO: No instances of this class are every constructed, and it has no instance methods...
    #       do we still want this to be a class?

    include ToknInternal

    # Compile a Tokenizer DFA from a token definition script.
    #
    def self.from_script(script)
      td = TokenDefParser.new
      td.parse(script)
    end

    # Compile a Tokenizer DFA from a token definition script, generating pdfs while doing so
    #
    def self.from_script_with_pdf(script)
      td = TokenDefParser.new
      td.generate_pdf = true
      td.parse(script)
    end


    private


  end

end  # module Tokn
