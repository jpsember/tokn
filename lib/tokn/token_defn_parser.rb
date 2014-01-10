module ToknInternal

req 'reg_parse dfa_builder'

  # Parses a token definition script, and generates an NFA that
  # is capable of recognizing and distinguishing between the various
  # tokens.
  #
  # Each line in the script is one of
  #
  #   # ...comment... (the # must appear as the first character in the line)
  #
  #   <tokenname> ':' <regex>
  #
  #
  # A <tokenname> must be an 'identifier' (alphanumeric, with first character a letter (or '_')).
  # If the first character is '_', the token is treated as an 'anonymous' token; these can
  # appear in the curly brace portions of previous reg. expr. entries, but do not appear as tokens in the
  # generated NFA.
  #
  class TokenDefParser

    attr_reader :dfa

    # Compile a token definition script into a DFA
    #
    def initialize(script)
      @script = script
      parseScript
    end

    private

    def parseScript
      nextTokenId = 0

      # List of tokens entries, including anonymous ones
      @tokenListBig = []

      # List of tokens names, excluding anonymous ones
      tokenListSmall = []

      # Maps token name to token entry
      @tokenNameMap = {}

      @lines = @script.split("\n")

      @lines.each_with_index do |line, lineNumber|

        line.strip!

        # If line is empty, or starts with '#', it's a comment
        if line.length == 0 || line[0] == '#'
          next
        end

        if !(line =~ TOKENNAME_EXPR)
          raise ParseException, "Syntax error, line #"+lineNumber.to_s+": "+line
        end

        pos = line.index(":")

        tokenName = line[0,pos].strip()

        expr = line[pos+1..-1].strip()

        rex = RegParse.new(expr, @tokenNameMap)

        # Give it the next available token id, if it's not an anonymous token
        tkId = nil
        if tokenName[0] != '_'
          tkId = nextTokenId
          nextTokenId += 1
        end

        tkEntry = [tokenName, rex, @tokenListBig.size, tkId]

        if @tokenNameMap.has_key?(tokenName)
          raise ParseException, "Duplicate token name: "+line
        end


        @tokenListBig.push(tkEntry)
        @tokenNameMap[tkEntry[0]] = tkEntry

        if tkId
          tokenListSmall.push(tokenName)
        end

      end

      combined = combineTokenNFAs()

      dfa = DFABuilder.nfa_to_dfa(combined)

      @dfa = Tokn::DFA.new(tokenListSmall, dfa)
    end

    # Combine the individual NFAs constructed for the token definitions into
    # one large NFA, each augmented with an edge labelled with the appropriate
    # token identifier to let the tokenizer see which token led to the final state.
    #
    def combineTokenNFAs
      baseId = 0
      startState = nil

      @tokenListBig.each do |tokenName, regParse, index, tokenId|

        # Skip anonymous token definitions
        if !tokenId
          next
        end

        oldToNewMap, baseId = regParse.startState.duplicateNFA( baseId)

        dupStart = oldToNewMap[regParse.startState]

        # Transition from the expression's end state (not a final state)
        # to a new final state, with the transitioning edge
        # labelled with the token id (actually, a transformed token id to distinguish
        # it from character codes)
        dupEnd = oldToNewMap[regParse.endState]

        dupfinalState = State.new(baseId)
        baseId += 1
        dupfinalState.finalState = true

        # Why do I need to add 'ToknInternal.' here?  Very confusing.
        dupEnd.addEdge(CodeSet.new(ToknInternal.token_id_to_edge_label(tokenId)), dupfinalState)

        if !startState
          startState = dupStart
        else
          # Add an e-transition from the start state to this expression's start
          startState.addEdge(CodeSet.new(EPSILON),dupStart)
        end
      end
      startState
    end

    # Regex for token names preceding regular expressions
    #
    TOKENNAME_EXPR = Regexp.new("[_A-Za-z][_A-Za-z0-9]*\s*:\s*")

  end

end  # module ToknInternal
