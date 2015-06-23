
req 'code_set state tokn_const'

module ToknInternal

  # Exception thrown if problem parsing regular expression
  #
  class ParseException < Exception; end

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
  #      | BRACKETEXPR
  #      | CHARCLASS
  #
  #   CHARCLASS -> '\d'
  #      | '\w'
  #      | CHARCODE
  #
  #   BRACKETEXPR -> '[' '^'?  SET+ ']'
  #
  #   SET -> CHARCODE
  #      | CHARCODE '-' CHARCODE
  #
  #   CHARCODE ->
  #         a |  b |  c  ...   any printable except {,},[, etc.
  #      |  \xhh                  hex value from 00...ff
  #      |  \uhhhh                hex value from 0000...ffff (e.g., unicode)
  #      |  \f | \n | \r | \t     formfeed, linefeed, return, tab
  #      |  \s                    a space (' ')
  #      |  \d                    digit: [0-9]
  #      |  \w                    word character: [0-9a-zA-Z_]
  #      |  \*                    where * is some other non-alphabetic
  #                                character that needs to be escaped
  #
  # The parser performs recursive descent parsing;
  # each method returns an NFA represented by
  # a pair of states: the start and end states.
  #
  class RegParse

    @@digit_code_set = nil
    @@wordchar_code_set = nil

    attr_reader :startState, :endState

    # Construct a parser and perform the parsing
    # @param script script to parse
    # @param tokenDefMap if not nil, a map of previously parsed regular expressions
    #     (mapping names to ids) to be consulted if a curly brace expression appears
    #     in the script
    #
    def initialize(script, tokenDefMap = nil)
      @script = filter_ws(script)
      @nextStateId = 0
      @tokenDefMap = tokenDefMap
      parseScript
    end

    private

    # Filter out all spaces and tabs
    #
    def filter_ws(s)
      result = ''

      escaped = false

      prev_ch = nil
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
      s << "\n Expression being parsed: " << @script
      raise ParseException, msg + ": "+s
    end

    # Read next character as a hex digit
    #
    def readHex
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

    # Parse character definition (CHARCODE) from input
    #
    def parseChar

      c = read

      val = c.ord

      if "{}[]*?+|-^()".include?(c) or val < 0x20
        abort "Unexpected or unescaped character '#{c}' (\##{val})"
      end

      if c == '\\'

        c = read

        if "xX".include? c
          val = (readHex() << 4) | readHex()
        elsif "uU".include? c
          val = (readHex() << 12) | (readHex() << 8) | (readHex() << 4) | readHex()
        else
          if c == 'f'
            val = "\f".ord
          elsif c == 'r'
            val == "\r".ord
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

      return val
    end

    def self.digit_code_set
      if @@digit_code_set == nil
        cset = CodeSet.new
        cset.add('0'.ord,1 + '9'.ord)
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
        @@wordchar_code_set = cset
      end
      @@wordchar_code_set
    end

    def parseDigitClass
      read
      read
      sA = newState
      sB = newState
      sA.addEdge(RegParse.digit_code_set, sB)
      [sA,sB]
    end

    def parseWordCharClass
      read
      read
      sA = newState
      sB = newState
      sA.addEdge(RegParse.wordchar_code_set, sB)
      [sA,sB]
    end

    def parseCharClass

      if peek(0) == '\\'
        c2 = peek(1)
        if c2 == 'd'
          return parseDigitClass
        elsif c2 == 'w'
          return parseWordCharClass
        end
      end

      val = parseChar

      # Construct a pair of states with an edge between them
      # labelled with this character code

      sA = newState
      sB = newState
      cset = CodeSet.new
      cset.add(val)
      sA.addEdge(cset, sB)
      return [sA,sB]
    end

    def parseScript
      # Set up the input scanner
      @char_buffer = []
      @cursor = 0

      exp = parseE
      @startState = exp[0]
      @endState = exp[1]
    end

    def newState
      s = State.new(@nextStateId)
      @nextStateId += 1
      return s
    end

    def parseSET
      u = parseChar
      v = u+1
      if readIf('-')
        v = parseChar() + 1
        if v <= u
          abort "Illegal range"
        end
      end
      return u,v
    end

    def parseBRACKETEXPR
      read('[')
      negated = readIf('^')
      rs = CodeSet.new

      u,v = parseSET
      rs.add(u,v)

      while not readIf(']')
        u,v = parseSET
        rs.add(u,v)
      end
      if negated
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

    def parseTokenDef
      read('{')
      name = ''
      while !readIf('}')
        name += read
      end
      if name  !~ TOKENREF_EXPR
        abort "Problem with token name"
      end
      tokInfo = nil
      if @tokenDefMap
        tokInfo = @tokenDefMap[name]
      end
      if !tokInfo
        abort "Undefined token"
      end
      rg = tokInfo[1]

      oldToNewMap, @nextStateId = rg.startState.duplicateNFA(@nextStateId)

      newStart = oldToNewMap[rg.startState]
      newEnd = oldToNewMap[rg.endState]

      [newStart, newEnd]
    end

    def parseP
      ch = peek(0)
      if ch == '('
        read
        e1 = parseE
        read ')'
      elsif ch == '{'
        e1 = parseTokenDef
      elsif ch == '['
        e1 = parseBRACKETEXPR
      else
        e1 = parseCharClass
      end
      e1
    end

    def parseE
      e1 = parseJ
      if readIf('|')
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
        e1[1].addEps(e2[0])
        e1 = [e1[0],e2[1]]
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
      e1
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

    def readIf(expChar)
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
  end

end  # module ToknInternal
