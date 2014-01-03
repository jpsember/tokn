require 'json'

req 'code_set state token_defn_parser'

module Tokn

  # A DFA for tokenizing; includes pointer to a start state, and
  # a list of token names
  #
  class DFA

    include ToknInternal

    # Compile a Tokenizer DFA from a token definition script.
    # If persistPath is not null, it first checks if the file exists and
    # if so, assumes it contains (in JSON form) a previously compiled
    # DFA matching this script, and reads the DFA from it.
    # Second, if no such file exists, it writes the DFA to it after compilation.
    #
    def self.from_script(script, persistPath = nil)

      if persistPath and File.exist?(persistPath)
        return self.from_file(persistPath)
      end


      td = TokenDefParser.new(script)
      dfa = td.dfa

      if persistPath
        FileUtils.write_text_file(persistPath, dfa.serialize())
      end

      dfa
    end

    # Similar to from_script, but reads the script into memory from
    # the file at scriptPath.
    #
    def self.from_script_file(scriptPath, persistPath = nil)
      self.from_script(FileUtils.read_text_file(scriptPath), persistPath)
    end

    # Compile a Tokenizer DFA from a text file (that contains a
    # JSON string)
    #
    def self.from_file(path)
      from_json(FileUtils.read_text_file(path))
    end

    # Compile a Tokenizer DFA from a JSON string
    #
    def self.from_json(jsonStr)

      h = JSON.parse(jsonStr)

      version = h["version"]

      if !version || version.floor != VERSION.floor
        raise ArgumentError,"Bad or missing version number: #{version}, expected #{VERSION}"
      end

      tNames = h["tokens"]
      stateInfo = h["states"]

      st = []                      # (key_val),i
      stateInfo.each_with_index do |_,i|
        st.push(State.new(i))
      end

      st.each do |s|
        finalState, edgeList = stateInfo[s.id]
        s.finalState = finalState
        edgeList.each do |edge|
          label,destState = edge
          cr = CodeSet.new()
          cr.setArray(label)
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
    def tokenName(tokenId)
      if !tokenId
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

    # Get id of token given its name
    # @param tokenName name of token
    # @return nil if there is no token with that name
    #
    def tokenId(tokenName)
      @tokenIdMap[tokenName]
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

      h = {"version"=>VERSION, "tokens"=>tokenNames}


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


    VERSION = 1.0

    def stateToList(state)
      list = [state.finalState?]
      ed = []
      state.edges.each do |lbl, dest|
        edInfo = [lbl.array, dest.id]
        ed.push(edInfo)
      end
      list.push(ed)

      list
    end

  end

end  # module Tokn
