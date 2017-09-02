module Tokn

  # Support for compiling and serializing DFAs
  #
  class DFACompiler

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
    #  }
    #
    # Each state has this format:
    #  [ final_state (boolean),
    #   [edge0, edge1, ...]
    #  ]
    #
    # Edge:
    #  [label, destination id (integer)]
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
        list = [state.final_state ? 1 : 0]
        ed = []
        state.edges.each do |lbl, dest|
          elements = self.compile_elements_for_json(lbl.elements)
          ed << elements
          ed << dest.id
        end
        list.push(ed)
        state_info.push(list)
      end
      dict["states"] = state_info

      JSON.generate(dict)
    end


    private


    def self.compile_elements_for_json(elements)
      result = []
      (0...elements.length).step(2).each do |index|
        a = elements[index]
        b = elements[index + 1]

        if b == a + 1
          result << a.to_f
        else
          b = 0 if b == CODEMAX
          result << a << b
        end
      end
      # If array has only one element, return the element; otherwise, the array
      if result.size == 1
        result[0]
      else
        result
      end
    end

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
