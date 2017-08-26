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

    attr_reader :startState, :tokenNames

    # Construct a DFA, given a list of token names and a starting state.
    #
    def initialize(tokenNameList, startState)

      if (startState.id != 0)
        raise ArgumentError, "Start state id must be zero"
      end

      @tokenNames = tokenNameList
      @startState = startState
      @tokenIdMap = {}
      @tokenNames.each_with_index do |name, i|
        @tokenIdMap[name] = i
      end

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
        if tokenId < 0 || tokenId >= tokenNames.size
          raise IndexError, "No such token id:#{tokenId}"
        end
        nm = tokenNames[tokenId]
      end
      nm
    end

    def tokenId(tokenName)
      token_id(tokenName)
    end

    # Get id of token given its name, or nil if no such token found
    #
    def token_id(token_name)
      @tokenIdMap[token_name]
    end


    # Serialize this DFA to a JSON string.
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
    def serialize

      h = {"version"=>DFA.version, "tokens"=>tokenNames}

      stateSet,_,_ = startState.reachableStates

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

      if stateList[0] != startState
        raise ArgumentError, "bad start state"
      end

      stateInfo = []
      stateList.each do |st|
        stateInfo.push(stateToList(st))
      end
      h["states"] = stateInfo

      JSON.generate(h)
    end


    private


    def stateToList(state)
      list = [state.finalState?]
      ed = []
      state.edges.each do |lbl, dest|
        edInfo = [lbl.elements, dest.id]
        ed.push(edInfo)
      end
      list.push(ed)

      list
    end

  end

end  # module Tokn
