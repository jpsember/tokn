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

    # Serialize DFA to a JSON string.
    # The DFA in JSON form has this structure:
    #
    #  {
    #    "version" => version number (float)
    #    "tokens" => array of token names (strings)
    #    "states" => array of states, ordered by id (0,1,..)
    #    "final" => id of final state
    #  }
    #
    # Each state is a list of edges:
    #  [edge0, edge1, ...]
    #
    # Each edge is a list:
    #  [label, destination id]
    #
    # Labels are arrays of integers, exactly the structure of
    # a CodeSet array.
    #
    def self.serialize(dfa)

      require "json"

      dict = {"version" => DFA.version, "tokens" => dfa.token_names}

      state_info = []

      state_list = self.get_ordered_state_list(dfa)
      state_list.each do |state|
        if state.final_state
          raise "multiple final states" if dict.include? "final"
          dict["final"] = state.id
        end

        edge_list = []
        state.edges.each do |lbl, dest|
          edge_list << lbl.to_json
          edge_list << dest.id
        end
        state_info << edge_list
      end
      dict["states"] = state_info

      JSON.generate(dict)
    end


    private


    def self.get_ordered_state_list(dfa)
      raise ArgumentError, "Bad start state" if dfa.start_state.id != 0
      state_list = []
      id_to_state_map = {}
      dfa.start_state.reachable_states.each{|st| id_to_state_map[st.id] = st}
      id_to_state_map.size.times do |id|
        state = id_to_state_map[id] or raise ArgumentError, "unexpected state ids"
        state_list << state
      end
      state_list
    end

  end

end  # module Tokn
