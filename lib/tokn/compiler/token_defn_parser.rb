module ToknInternal

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

    attr_accessor :generate_pdf

    def initialize
      @generate_pdf = false
    end

    # Compile a token definition script into a DFA
    #
    def parse(script)
      nextTokenId = 0

      token_records = []
      token_names = []

      # Maps token name to token entry
      @tokenNameMap = {}

      @lines = script.split("\n")

      # Join lines that have been ended with '\' to their following lines;
      # only do this if there's an odd number of '\' at the end
      joined_lines = []
      accum = nil
      @lines.each do |line|
        # puts "examining line: '#{line}'"
        trailing_backslash_count = 0
        while line.length > trailing_backslash_count && line[-1-trailing_backslash_count] == '\\'
          trailing_backslash_count += 1
        end
        if (trailing_backslash_count % 2 == 1)
          if !accum
            accum = ''
          end
          accum << line[0...-1]
        else
          if accum
            accum << line
            line = accum
            accum = nil
          end
          joined_lines << line
        end
      end
      if accum
         raise ParseException, "Incomplete final line: "+script
      end
      @lines = joined_lines

      # Now that we've stitched together lines where there were trailing \ characters,
      # process each line as a complete token definition

      @lines.each_with_index do |line, lineNumber|

        # Strip whitespace only from the left side (which will strip all of
        # it, if the entire line is whitespace).  We want to preserve any
        # special escaped whitespace on the right side.
        line.lstrip!

        # If line is empty, or starts with '#', it's a comment
        if line.length == 0 || line[0] == '#'
          next
        end

        if !(line =~ TOKENNAME_EXPR)
          raise ParseException, "Syntax error, line #"+lineNumber.to_s+": "+line
        end

        pos = line.index(":")

        tokenName = line[0,pos].strip()

        expr = line[pos+1..-1]

        rex = RegParse.new(expr, @tokenNameMap)

        # Give it the next available token id, if it's not an anonymous token
        tkId = nil
        if tokenName[0] != '_'
          tkId = nextTokenId
          nextTokenId += 1
        end

        tkEntry = TokenEntry.new(tokenName, rex, tkId)

        if @tokenNameMap.has_key?(tokenName)
          raise ParseException, "Duplicate token name: "+line
        end
        @tokenNameMap[tkEntry.name] = tkEntry

        next if tkId.nil?

        token_records << tkEntry
        token_names << tokenName

      end

      combined = combineTokenNFAs(token_records)

      builder = DFABuilder.new(combined)
      builder.generate_pdf = @generate_pdf
      dfa = builder.nfa_to_dfa

      Tokn::DFA.new(token_names, dfa)
    end

    # Combine the individual NFAs constructed for the token definitions into
    # one large NFA, each augmented with an edge labelled with the appropriate
    # token identifier to let the tokenizer see which token led to the final state.
    #
    def combineTokenNFAs(token_records)

      # Create a new distinguished start state

      start_state = State.new(0)
      baseId = 1

      token_records.each do |tk|
        regParse = tk.reg_ex

        oldToNewMap, baseId = regParse.start_state.duplicateNFA(baseId)

        dupStart = oldToNewMap[regParse.start_state]

        # Transition from the expression's end state (not a final state)
        # to a new final state, with the transitioning edge
        # labelled with the token id (actually, a transformed token id to distinguish
        # it from character codes)
        dupEnd = oldToNewMap[regParse.endState]

        dupfinal_state = State.new(baseId)
        baseId += 1
        dupfinal_state.final_state = true

        # Why do I need to add 'ToknInternal.' here?  Very confusing.
        dupEnd.addEdge(CodeSet.new(ToknInternal.token_id_to_edge_label(tk.id)), dupfinal_state)

        # Add an e-transition from the start state to this expression's start
        start_state.addEdge(CodeSet.new(EPSILON),dupStart)
      end
      start_state
    end

    # Regex for token names preceding regular expressions
    #
    TOKENNAME_EXPR = Regexp.new("[_A-Za-z][_A-Za-z0-9]*\s*:\s*")

  end


  class TokenEntry

    attr_reader :name, :reg_ex, :id

    def initialize(name, reg_ex, id)
      @name = name
      @reg_ex = reg_ex
      @id = id
    end

  end

end  # module ToknInternal
