module Tokn

  # A DFA for tokenizing; includes pointer to a start state, and
  # a list of token names
  #
  class DFA

    def self.version
      2.0
    end

    include ToknInternal

    # Compile a Tokenizer DFA from a JSON string
    #
    def self.from_json(jsonStr)
      require "json"
      h = JSON.parse(jsonStr)
      version = h["version"]

      if !version || version.floor != DFA.version.floor
        raise ArgumentError,"Bad or missing version number: #{version}, expected #{DFA.version}"
      end

      tNames = h["tokens"]
      stateInfo = h["states"]
      final_state_id = h["final"] or raise "missing final state"

      st = []
      stateInfo.each_with_index do |_,i|
        st.push(State.new(i))
      end

      st.each do |s|
        edgeList = stateInfo[s.id][0]
        s.final_state = (s.id == final_state_id)
        cursor = 0
        while cursor < edgeList.size
          label = edgeList[cursor]
          destState = edgeList[cursor+1]
          cursor += 2

          cr = CodeSet.new()
          cr.elements = DFA::decompile_elements_from_json(label)
          s.addEdge(cr, st[destState])
        end
      end

      DFA.new(tNames, st[0])

    end

    attr_reader :start_state, :token_names

    # Construct a DFA, given a list of token names and a starting state.
    #
    def initialize(token_name_list, start_state)

      if (start_state.id != 0)
        raise ArgumentError, "Start state id must be zero"
      end

      @token_names = token_name_list
      @start_state = start_state
      @token_id_map = nil
    end

    # Determine the name of a token, given its id.
    # Returns <UNKNOWN> if its id is UNKNOWN_TOKEN, or <EOF> if
    # the token_id is nil.  Otherwise, assumes token_id is 0 ... n-1, where
    # n is the number of token names in the DFA.
    #
    def token_name(token_id)
      if token_id.nil?
        "<EOF>"
      elsif token_id == UNKNOWN_TOKEN
        "<UNKNOWN>"
      else
        if token_id < 0 || token_id >= @token_names.size
          raise IndexError, "No such token id:#{token_id}"
        end
        @token_names[token_id]
      end
    end

    # Get id of token given its name, or nil if no such token found
    #
    def token_id(token_name)
      if @token_id_map.nil?
        @token_id_map = {}
        @token_names.each_with_index do |name, i|
          @token_id_map[name] = i
        end
      end
      @token_id_map[token_name]
    end


    private


    def self.decompile_elements_from_json(elements)
      # If elements is not an array, wrap it as a single element of an array
      if !(elements.is_a? Array)
        elements = [elements]
      end

      result = []
      cursor = 0
      while cursor < elements.length
        a = elements[cursor]
        cursor += 1
        if a.is_a? Integer
          b = elements[cursor]
          cursor += 1
          if b == 0
            b = CODEMAX
          end
        else
          a = a.to_i
          b = a + 1
        end
        result << a << b
      end
      result
    end

  end


end  # module Tokn
