require_relative 'tools'
req('code_set state')

module ToknInternal
  
  # Exception thrown if problem parsing regular expression
  #
  class ParseException < Exception
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
  #      | '[^' SETSEQ ']'     A code not appearing in the set
  #      | '[' SETSEQ ']'        
  #      | CHARCODE
  #
  #   SETSEQ -> SET SETSEQ
  #           | SET 
  #
  #   SET -> CHARCODE 
  #           | CHARCODE '-' CHARCODE
  #   
  #   CHARCODE ->   
  #            a |  b |  c  ...   any printable except {,},[, etc.
  #        |  \xhh                  hex value from 00...ff
  #        |  \uhhhh                hex value from 0000...ffff (e.g., unicode)
  #        |  \f | \n | \r | \t     formfeed, linefeed, return, tab
  #        |  \s                    a space (' ')
  #        |  \*                    where * is some other non-alphabetic
  #                                  character that needs to be escaped
  #
  # The parser performs recursive descent parsing;
  # each method returns an NFA represented by
  # a pair of states: the start and end states.
  #
  class RegParse
    
    attr_reader :startState, :endState
    
    # Construct a parser and perform the parsing
    # @param script script to parse
    # @param tokenDefMap if not nil, a map of previously parsed regular expressions
    #     (mapping names to ids) to be consulted if a curly brace expression appears 
    #     in the script
    #
    def initialize(script, tokenDefMap = nil) 
      @script = script.strip
      @nextStateId = 0
      @tokenDefMap = tokenDefMap
      parseScript
    end 
  
     
    def inspect   
      s = "RegParse: #{@script}"
      s += " start:"+d(@startState)+" end:"+d(@endState)
      return s
    end 
   
    private 
  
    # Raise a ParseException, with a helpful message indicating
    # the parser's current location within the string
    #
    def abort(msg)
      # Assume we've already read the problem character
      i = @cursor - 1
      s = ''
      if i > 4
        s += '...'
      end
      s +=  @script[i-3...i] || ""
      s += ' !!! '
      s += @script[i...i+3] || ""
      if i +3 < @script.size
        s += '...'
      end
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
      
      if "{}[]*?+|-^()".include?(c) or val <= 0x20
        abort "Unexpected or unescaped character"
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
              abort "Unsupported escape sequence ("+c+")"
            end
            val = c.ord
          end 
        end
      end
      
      return val
    end
  
    
    def parseCharNFA
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
    
     
     
    def dbInfo
      j = @cursor
      k = j + 5
      if k >= @script.size
        return @script[j..k]+"<<<== end"
      else
        return @script[j..k]+"..."
      end
    end
    
    def parseScript
      # Set up the input scanner
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
  
    def parseSETSEQ
      db = false
      
      !db || pr("parseSETSEQ\n")
      
      read('[')
      negated = readIf('^')
      !db || pr(" negated=%s\n",negated)
       
      rs = CodeSet.new
      
      u,v = parseSET
      rs.add(u,v)
      !db || pr(" initial set=%s\n",d(rs))
  
      while not readIf(']')
        u,v = parseSET
        rs.add(u,v)
        !db || pr("  added another; %s\n",d(rs))
      end  
      if negated
        rs.negate
        !db || pr(" negated=%s\n",d(rs))
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
      # pr("name=[%s], TR=[%s], match=[%s]\n",d(name),d(TOKENREF_EXPR),d(name =~ TOKENREF_EXPR))
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
      ch = peek
      if ch == '('
        read
        e1 = parseE
        read ')' 
      elsif ch == '{' 
        e1 = parseTokenDef
      elsif ch == '[' 
        e1 = parseSETSEQ
      else
        e1 = parseCharNFA
      end
      return e1
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
      return e1
    end
    
    def parseJ
      e1 = parseQ
      p = peek
      if p and not "|)".include? p
        e2 = parseJ
        e1[1].addEps(e2[0])
        e1 = [e1[0],e2[1]]
      end
      
      return e1
    end
    
    def parseQ
      e1 = parseP
      p = peek
      
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
        # e1[0].generatePDF("optional")
      end
      return e1
    end
    
      
    def peek(mustExist = false)
      # skip over any non-linefeed whitespace
      while @cursor < @script.size && " \t".index(@script[@cursor])
        @cursor += 1
      end
      if mustExist or @cursor < @script.size
        @script[@cursor]
      else
        nil
      end
    end
    
    def readIf(expChar)
      r = (peek == expChar)
      if r
        read
      end
      return r
    end
   
    def read(expChar = nil)
      ch = peek
      if ch and ((not expChar) or ch == expChar)
        @cursor += 1
        ch
      else
        abort 'Unexpected end of input' 
      end
    end
  end
  
end  # module ToknInternal
