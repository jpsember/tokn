require_relative 'token_defn_parser'

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
    #  [ finalState (boolean),
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

      h = {"version" => DFA.version, "tokens" => dfa.token_names}

      stateSet,_,_ = dfa.start_state.reachableStates

      idToStateMap = {}
      stateSet.each{ |st| idToStateMap[st.id] = st }

      stateList = []

      nextId = 0
      idToStateMap.each_pair do |id, st|
        if nextId != id
          raise ArgumentError, "unexpected state ids"
        end
        nextId += 1

        stateList.push(st)
      end

      if stateList.size == 0
        raise ArgumentError, "bad states"
      end

      if stateList[0] != dfa.start_state
        raise ArgumentError, "bad start state"
      end

      stateInfo = []
      stateList.each do |state|
        list = [state.finalState?]
        ed = []
        state.edges.each do |lbl, dest|
          edInfo = [lbl.elements, dest.id]
          ed.push(edInfo)
        end
        list.push(ed)
        stateInfo.push(list)
      end
      h["states"] = stateInfo

      JSON.generate(h)
    end

  end

end  # module Tokn
