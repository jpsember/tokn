require_relative 'token_defn_parser'

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

      h = JSON.parse(jsonStr)
      version = h["version"]

      if !version || version.floor != DFA.version.floor
        raise ArgumentError,"Bad or missing version number: #{version}, expected #{DFA.version}"
      end

      tNames = h["tokens"]
      stateInfo = h["states"]

      st = []
      stateInfo.each_with_index do |_,i|
        st.push(State.new(i))
      end

      st.each do |s|
        finalState, edgeList = stateInfo[s.id]
        s.finalState = finalState
        edgeList.each do |edge|
          label,destState = edge
          cr = CodeSet.new()
          cr.elements = label
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
    # the tokenId is nil.  Otherwise, assumes tokenId is 0 ... n-1, where
    # n is the number of token names in the DFA.
    #
    def token_name(tokenId)
      if tokenId.nil?
        nm = "<EOF>"
      elsif tokenId == UNKNOWN_TOKEN
        nm = "<UNKNOWN>"
      else
        if tokenId < 0 || tokenId >= @token_names.size
          raise IndexError, "No such token id:#{tokenId}"
        end
        nm = @token_names[tokenId]
      end
      nm
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

  end

end  # module Tokn
