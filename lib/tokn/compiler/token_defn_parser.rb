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
      next_token_id = 0

      token_records = []

      # Maps token name to token entry
      @tokenNameMap = {}

      script_lines = script.split("\n")
      @original_line_numbers = []

      # Join lines that have been ended with '\' to their following lines;
      # only do this if there's an odd number of '\' at the end

      @lines = []
      accum = nil
      accum_start_line = nil

      script_lines.each_with_index do |line, original_line_number|

        trailing_backslash_count = 0
        while line.length > trailing_backslash_count && line[-1-trailing_backslash_count] == '\\'
          trailing_backslash_count += 1
        end

        if accum.nil?
          accum = ""
          accum_start_line = original_line_number
        end

        if (trailing_backslash_count % 2 == 1)
          accum << line[0...-1]
        else
          accum << line
          @lines << accum
          @original_line_numbers << accum_start_line
          accum = nil
        end
      end

      if !accum.nil?
         raise ParseException, "Incomplete final line: #{script}"
      end

      # Now that we've stitched together lines where there were trailing \ characters,
      # process each line as a complete token definition

      @lines.each_with_index do |line, line_index|
        line_number = 1 + @original_line_numbers[line_index]

        # Strip whitespace only from the left side (which will strip all of
        # it, if the entire line is whitespace).  We want to preserve any
        # special escaped whitespace on the right side.
        line.lstrip!

        # If line is empty, or starts with '#', it's a comment
        if line.length == 0 || line[0] == '#'
          next
        end

        if !(line =~ TOKENNAME_EXPR)
          raise ParseException.build("Syntax error", line_number, line)
        end

        pos = line.index(":")

        tokenName = line[0,pos].strip()

        expr = line[pos+1..-1]

        rex = RegParse.new(expr, @tokenNameMap, line_number)

        # Give it the next available token id, if it's not an anonymous token; else -1

        token_id = -1
        if tokenName[0] != '_'
          token_id = next_token_id
          next_token_id += 1
        end

        entry = TokenEntry.new(tokenName, rex, token_id)

        if @tokenNameMap.has_key?(tokenName)
          raise ParseException.build("Duplicate token name",line_number,line)
        end
        @tokenNameMap[entry.name] = entry

        next if entry.id < 0

        if accepts_zero_characters(rex.start_state, rex.endState)
          raise ParseException.build("Zero-length tokens accepted",line_number,line)
        end

        token_records << entry
      end

      combined = combine_token_nfas(token_records)

      builder = DFABuilder.new(combined)
      builder.generate_pdf = @generate_pdf
      dfa = builder.nfa_to_dfa

      apply_redundant_token_filter(token_records, dfa)

      Tokn::DFA.new(token_records.map{|x| x.name}, dfa)
    end

    # Determine if regex accepts zero characters
    def accepts_zero_characters(start_state, end_state)
      marked_states = Set.new
      state_stack = [start_state]
      while !state_stack.empty?
        state = state_stack.pop
        next if marked_states.include? state.id
        marked_states.add(state.id)
        return true if state.id == end_state.id
        state.edges.each do |label, dest_state|
          next unless label.contains? EPSILON
          state_stack << dest_state
        end
      end
      false
    end

    # Determine if any tokens are redundant
    #
    def apply_redundant_token_filter(token_records, start_state)

      recognized_token_id_set = Set.new

      start_state.reachable_states.each do |state|
        state.edges.each do |label, dest|
          next unless dest.final_state
          token_id = ToknInternal::edge_label_to_token_id(label.elements[0])
          recognized_token_id_set.add(token_id)
        end
      end

      unrecognized = []

      token_records.each do |rec|
        next if recognized_token_id_set.include? rec.id
        unrecognized << rec.name
      end

      return if unrecognized.empty?

      raise ParseException, "Redundant token(s) found: #{unrecognized.join(", ")}"
    end

    # Combine the individual NFAs constructed for the token definitions into
    # one large NFA, each augmented with an edge labelled with the appropriate
    # token identifier to let the tokenizer see which token led to the final state.
    #
    def combine_token_nfas(token_records)

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
