# require_relative 'code_set'
# require_relative 'state'
# require_relative 'tokn_const'

module ToknInternal

  # Exception thrown if problem parsing regular expression
  #
  class ParseException < Exception

    def self.build(message, line_number, line)
      unless line_number.nil?
        message = message + ", line #{line_number}; #{line}"
      end
      ParseException.new(message)
    end

  end

  # Parses a single regular expression from a string.
  # Produces an NFA with distinguished start and end states
  # (none of these states are marked as final states)
  #
  # Here is the grammar for regular expressions.  Spaces are ignored,
  # and can be liberally sprinkled within the regular expressions to
  # aid readability.  To represent a space, the \s escape sequence must be used.
  # See the file 'sampletokens.txt' for some examples.
  #
  #   Expressions have one of these types:
  #
  #   E : base class
  #   J : a Join expression, formed by concatenating one or more together
  #   Q : a Quantified expression; followed optionally by '*', '+', or '?'
  #   P : a Parenthesized expression, which is optionally surrounded with (), {}, []
  #
  #   E -> J '|' E
  #      | J
  #
  #   J -> Q J
  #      | Q
  #
  #   Q -> P '*'
  #      | P '+'
  #      | P '?'
  #      | P
  #
  #   P -> '(' E ')'
  #      | '{' TOKENNAME '}'
  #      | '$' TOKENNAME
  #      | '^' P
  #      | BRACKETEXPR
  #      | CODE_SET
  #
  #   BRACKETEXPR -> '[' SET_OPTNEG ']'
  #
  #   SET_OPTNEG -> SET+
  #      |  SET* '^' SET+
  #
  #   SET -> CODE_SET
  #      | CODE_SET '-' CODE_SET
  #
  #   CODE_SET ->
  #         a |  b |  c  ...   any printable except {,},[, etc.
  #      |  \xhh                  hex value from 00...ff
  #      |  \0xhh                 hex value from 00...ff
  #      |  \uhhhh                hex value from 0000...ffff (e.g., unicode)
  #      |  \f | \n | \r | \t     formfeed, linefeed, return, tab
  #      |  \s                    a space (' ')
  #      |  \d                    digit
  #      |  \w                    word character
  #      |  \*                    where * is some other non-alphabetic
  #                                character that needs to be escaped
  #
  # The parser performs recursive descent parsing;
  # each method returns an NFA represented by
  # a pair of states: the start and end states.
  #
  class RegParse

    @@counter = 0
    @@digit_code_set = nil
    @@wordchar_code_set = nil

    attr_reader :start_state, :endState

    # Construct a parser and perform the parsing
    # @param script script to parse
    # @param tokenDefMap a map of previously parsed regular expressions
    #     (mapping names to ids) to be consulted if a curly brace expression appears
    #     in the script
    #
    def initialize(script, tokenDefMap, orig_line_number)
      @orig_script = script
      @script = filter_ws(script)
      @nextStateId = 0
      @tokenDefMap = tokenDefMap
      @orig_line_number = orig_line_number
      parseScript
    end

    private

    # Filter out all spaces and tabs
    #
    def filter_ws(s)
      result = ''

      escaped = false

      for pos in 0..s.length - 1
        ch = s[pos]

        case ch
        when ' ','\t'
          if escaped
            escaped = false
          else
            ch = nil
          end
        when '\\'
          escaped = !escaped
        else
          escaped = false
        end

        if !ch.nil?
          result << ch
        end
      end
      result
    end

    # Raise a ParseException, with a helpful message indicating
    # the parser's current location within the string
    #
    def abort(msg)
      # Assume we've already read the problem character
      # TODO Test this code
      i = @cursor - 1 - @char_buffer.length
      s = ''
      if i > 4
        s += '...'
      end
      s +=  @script[i-3...i] || ""
      s += ' !!! '
      s += @script[i...i+3] || ""
      if i + 3 < @script.size
        s += '...'
      end
      raise ParseException.build(msg + ": " + s, @orig_line_number, @orig_script)
    end

    # Read next character as a hex digit
    #
    def read_hex
      v = read.upcase.ord
      if v >= 48 and v < 58
        return v - 48
      elsif v >= 65 and v < 71
        return v - 65 + 10
      else
        abort "Missing hex digit"
      end
    end

    NO_ESCAPE_CHARS = Regexp.new("[A-Za-z0-9]")

    def self.digit_code_set
      if @@digit_code_set == nil
        cset = CodeSet.new
        cset.add('0'.ord,1 + '9'.ord)
        cset.freeze
        @@digit_code_set = cset
      end
      @@digit_code_set
    end

    def self.wordchar_code_set
      if @@wordchar_code_set == nil
        cset = CodeSet.new
        cset.addSet(RegParse.digit_code_set)
        cset.add('a'.ord,1 + 'z'.ord)
        cset.add('A'.ord,1 + 'Z'.ord)
        cset.add('_'.ord)
        cset.freeze
        @@wordchar_code_set = cset
      end
      @@wordchar_code_set
    end

    def parse_digit_code_set
      read
      read
      RegParse.digit_code_set.makeCopy
    end

    def parse_word_code_set
      read
      read
      RegParse.wordchar_code_set.makeCopy
    end

    def parse_code_set(within_bracket_expr = false)

      # If starts with \, special parsing required
      if peek(0) != '\\'
        c = read
        val = c.ord
        if within_bracket_expr && c == '^'
          abort "Illegal character within [ ] expression: #{c}"
        end
      else
        c2 = peek(1)
        if c2 == 'd'
          return parse_digit_code_set
        elsif c2 == 'w'
          return parse_word_code_set
        end

        read

        c = read
        val = c.ord

        if c == '0'
          c = read
          abort "Unsupported escape sequence (#{c})" if !"xX".include? c
          val = (read_hex << 4) | read_hex
        elsif "xX".include? c
          val = (read_hex << 4) | read_hex
        elsif "uU".include? c
          val = (read_hex << 12) | (read_hex << 8) | (read_hex << 4) | read_hex
        else
          if c == 'f'
            val = "\f".ord
          elsif c == 'r'
            val = "\r".ord
          elsif c == 'n'
            val = "\n".ord
          elsif c == 't'
            val = "\t".ord
          elsif c == 's'
            val = " ".ord
          else
            if c =~ NO_ESCAPE_CHARS
              abort "Unsupported escape sequence (#{c})"
            end
            val = c.ord
          end
        end
      end
      CodeSet.new(val)
    end

    def parseScript
      # Set up the input scanner
      @char_buffer = []
      @cursor = 0

      exp = parseE
      @start_state = exp[0]
      @endState = exp[1]
    end

    # Debug utility to generate a pdf with a unique filename, based on counter
    #
    def dump_pdf(start_state)
      puts "parsed script:\n\n#{start_state.describe_state_machine}"
      start_state.generate_pdf("_SKIP_parseScript#{@@counter}.pdf")
      @@counter+=1
    end

    def newState
      s = State.new(@nextStateId)
      @nextStateId += 1
      return s
    end

    def parseSET
      code_set = parse_code_set(true)
      if read_if('-')
        u = code_set.single_value
        abort "Illegal bracket argument" if u.nil?
        v = parse_code_set(true).single_value
        abort "Illegal bracket argument" if v.nil?
        if v < u
          abort "Illegal range"
        end
        code_set = CodeSet.new(u,v+1)
      end
      code_set
    end

    def parseBRACKETEXPR
      read('[')
      rs = CodeSet.new
      expecting_set = true
      negated = false
      had_initial_set = false
      while true
        if !negated && read_if('^')
          negated = true
          expecting_set = true
        end

        if !expecting_set && read_if(']')
          break
        end

        set = parseSET
        expecting_set = false
        if negated
          if had_initial_set
            rs = rs.difference(set)
          else
            rs.addSet(set)
          end
        else
          rs.addSet(set)
          had_initial_set = true
        end
      end
      if negated && !had_initial_set
        rs.negate
      end

      if rs.empty?
        abort "Empty character range"
      end

      sA = newState
      sB = newState
      sA.addEdge(rs, sB)
      return [sA,sB]
    end

    TOKENREF_EXPR = Regexp.new('^[_A-Za-z][_A-Za-z0-9]*$')
    TOKENCHAR_EXPR = Regexp.new('[_A-Za-z0-9]')

    def parseTokenDef
      delim = read
      name = ''
      if delim == '$'
        while true
          q = peek(0)
          break if q !~ TOKENCHAR_EXPR
          name += read
        end
      else
        while true
          q = read
          break if q == '}'
          name += q
        end
      end
      if name  !~ TOKENREF_EXPR
        abort "Problem with token name"
      end

      tokInfo = @tokenDefMap[name]
      # Leading underscore is optional in this instance, as a convenience
      tokInfo ||= @tokenDefMap["_#{name}"]
      if !tokInfo
        abort "Undefined token"
      end
      rg = tokInfo.reg_ex

      oldToNewMap, @nextStateId = rg.start_state.duplicateNFA(@nextStateId)

      newStart = oldToNewMap[rg.start_state]
      newEnd = oldToNewMap[rg.endState]

      [newStart, newEnd]
    end

    def parseP
      ch = peek(0)
      if ch == '('
        read
        e1 = parseE
        read ')'
      elsif ch == '^'
        read
        e1 = parseP
        e1 = construct_complement(e1)
      elsif ch == '{' || ch == '$'
        e1 = parseTokenDef
      elsif ch == '['
        e1 = parseBRACKETEXPR
      else
        code_set = parse_code_set
        # Construct a pair of states with an edge between them
        # labelled with this code set
        sA = newState
        sB = newState
        sA.addEdge(code_set, sB)
        e1 = [sA,sB]
      end
      e1
    end

    def parseE
      e1 = parseJ
      if read_if('|')
        e2 = parseE

        u = newState
        v = newState
        u.addEps(e1[0])
        u.addEps(e2[0])
        e1[1].addEps(v)
        e2[1].addEps(v)
        e1 = [u,v]
      end
      e1
    end

    def parseJ
      e1 = parseQ
      p = peek(0)
      if p and not "|)".include? p
        e2 = parseJ
        #dump_pdf(e2[0])
        e1[1].addEps(e2[0])
        e1 = [e1[0],e2[1]]
        #dump_pdf(e1[0])
      end
      return e1
    end

    def parseQ
      e1 = parseP
      p = peek(0)

      if p == '*'
        read
        e1[0].addEps(e1[1])
        e1[1].addEps(e1[0])
      elsif p == '+'
        read
        e1[1].addEps(e1[0])
      elsif p == '?'
        read
        e1[0].addEps(e1[1])
      end
      create_new_final_state_if_nec(e1)
    end

    # If existing final state has outgoing edges,
    # then create a new final state, and add an e-transition to it from the old final state,
    # so the final state has no edges back
    #
    def create_new_final_state_if_nec(start_end_states)
      end_state = start_end_states[1]
      if !end_state.edges.empty?
        new_final_state = newState
        end_state.addEps(new_final_state)
        start_end_states[1] = new_final_state
      end
      start_end_states
    end

    def peek(position)
      while @char_buffer.length <= position
        ch = nil
        if @cursor < @script.size
          ch = @script[@cursor]
          @cursor += 1
        end
        @char_buffer << ch
      end
      @char_buffer[position]
    end

    def read_if(expChar)
      found = (peek(0) == expChar)
      if found
        read
      end
      found
    end

    def read(expChar = nil)
      ch = peek(0)
      @char_buffer.shift
      if ch and ((not expChar) or ch == expChar)
        ch
      else
        abort 'Unexpected end of input'
      end
    end

    def construct_complement(states)
      v = false

      nfa_start, nfa_end = states

      if v
        puts "\n\nconstruct_complement of:\n"
        puts nfa_start.describe_state_machine

        nfa_start.generate_pdf("../../_SKIP_nfa.pdf")
      end

      nfa_end.final_state = true

      builder = DFABuilder.new(nfa_start)
      builder.with_filter = false
      dfa_start_state = builder.nfa_to_dfa

      if v
        puts "\n\nconverted to DFA:\n"
        puts dfa_start_state.describe_state_machine
        dfa_start_state.generate_pdf("../../_SKIP_dfa.pdf")
      end

      states = dfa_start_state.reachable_states

      f = State.new(states.size)

      # + Let S be the DFA's start state
      # + Create F, a new final state
      # + for each state X in the DFA (excluding F):
      #   + if X is a final state, clear its final state flag;
      #   + otherwise:
      #     + construct C, a set of labels that is the complement of the union of any existing edge labels from X
      #     + if C is nonempty, add transition on C from X to F
      #     + if X is not the start state, add e-transition from X to F
      # + augment original NFA by copying each state X to a state X' (clearing final state flags)
      # + return [S', F']
      #

      # We don't process any final states in the above loop, because
      # we've sort of "lost" once we reach a final state no matter what
      # edges leave that state.  This is because we're looking for
      # substrings of the input string to find matches, instead of
      # just answering a yes/no recognition question for an (entire)
      # input string.

      states.each do |x|
        puts "processing state: #{x}" if v

        if x.final_state
          puts "...a final state" if v
          x.final_state = false
          next
        end

        codeset = CodeSet.new(0,CODEMAX)
        x.edges.each do |crs, s|
          puts "  edge to #{s}: #{crs}" if v
          codeset.difference!(crs)
        end
        puts " complement of edge code sets: #{codeset}" if v

        if !codeset.empty?
          x.addEdge(codeset, f)
          puts " adding edge to #{f.id} for #{codeset}" if v
        end

        puts " adding e-transition to #{f.id}" if v
        x.addEps(f)
      end
      f.final_state = true

      if v
        puts "\n\ncomplemented:\n"
        puts dfa_start_state.describe_state_machine
        dfa_start_state.generate_pdf("../../_SKIP_dfa_complemented.pdf")
      end

      states.add(f)

      # Build a map from the DFA state ids to new states within the NFA we're constructing
      #
      new_state_map = {}
      states.each do |x|
        x_new = newState
        new_state_map[x.id] = x_new
        puts "...mapping #{x.id} --> #{x_new.id}" if v
      end

      states.each do |x|
        x_new = new_state_map[x.id]
        x.edges.each do |code_set, dest_state|
          x_new.addEdge(code_set, new_state_map[dest_state.id])
        end
      end

      new_start = new_state_map[dfa_start_state.id]
      new_end = new_state_map[f.id]

      if v
        puts "returning new start #{new_start.id}, end #{new_end.id}"
        puts new_start.describe_state_machine
      end

      [new_start,new_end]
    end

  end

end  # module ToknInternal
