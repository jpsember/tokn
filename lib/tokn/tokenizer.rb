require_relative 'tools'
req('tokn_const dfa')

module Tokn

  # Extracts tokens from a script, given a previously constructed DFA.
  #
  class Tokenizer
    
    # Construct a tokenizer
    #
    # @param dfa the DFA to use
    # @param text the text to extract tokens from
    # @param skipName if not nil, tokens with this name will be skipped
    #
    def initialize(dfa, text, skipName = nil)
      @dfa = dfa
      @text = text
      if !text
        raise ArgumentError, "No text defined"
      end
      @skipTokenId = nil
      if skipName
        @skipTokenId = dfa.tokenId(skipName)
        if !@skipTokenId 
          raise ArgumentError, "No token with name "+skipName+" found"
        end
      end
      @lineNumber = 0
      @column = 0
      @cursor = 0
      @tokenHistory = []
      @historyPointer = 0  
    end
  
    # Determine next token (without reading it)
    #
    # Returns Token, or nil if end of input
    #
    def peek
      # if !@text
        # raise IllegalStateException, "No input text specified"
      # end
      
      db = false
      !db || warn("debug printing is on")
      !db || pr("peek, cursor=%d\n",@cursor)
      
      if @historyPointer == @tokenHistory.size
        while true # repeat until we find a non-skipped token, or run out of text
          break if @cursor >= @text.length
          
          bestLength = 0
          bestId = ToknInternal::UNKNOWN_TOKEN
          
          charOffset = 0
          state = @dfa.startState
          while @cursor + charOffset <= @text.length
            ch = nil
            if @cursor + charOffset < @text.length
              ch = @text[@cursor + charOffset].ord()
              !db || pr(" offset=%d, ch=%d (%s)\n",charOffset,ch,ch.chr)
            end
      
            nextState = nil
            
            # Examine edges leaving this state.
            # If one is labelled with a token id, we don't need to match the character with it;
            # store as best token found if length is longer than previous, or equal to previous
            # with higher id.
            
            # If an edge is labelled with the current character, advance to that state.
            
            edges = state.edges
            edges.each do |lbl,dest|
              a = lbl.array
              !db || pr("  edge lbl=%s, dest=%s\n",d(lbl),d(dest))
              if a[0] < ToknInternal::EPSILON
                newTokenId = ToknInternal::edgeLabelToTokenId(a[0])
                !db || pr("   new token id=%d\n",newTokenId)
              
                if (bestLength < charOffset || newTokenId > bestId)
                  bestLength, bestId = charOffset, newTokenId
                  !db || pr("     making longest found so far\n")
                end
              end
              
              if ch && lbl.contains?(ch)
                !db || pr("   setting next state to %s\n",d(dest))
                nextState = dest
                break
              end
            end 
            
            if !nextState
              break
            end
            state = nextState
            charOffset += 1 
            !db || pr(" advanced to next state\n")
          end
        
          if bestId == @skipTokenId
            @cursor += bestLength
            next
          end
          
          peekToken = Token.new(bestId, @text[@cursor, bestLength], 1 + @lineNumber, 1 + @column)
          
          @tokenHistory.push(peekToken)
          break # We found a token, so stop
        end  
      end
      
      ret = nil
      if @historyPointer < @tokenHistory.size
        ret = @tokenHistory[@historyPointer]
      end
      
      ret 
    end
  
      
    # Read next token
    # 
    # @param tokenName  if not nil, the (string) name of the token expected
    #
    # @raise TokenizerException if no more tokens,if unrecognized token, or
    # if token has different than expected name
    #  
    def read(tokenName = nil)
      token = peek()
      if !token
        raise TokenizerException,"No more tokens"
      end
      
      if token.id == ToknInternal::UNKNOWN_TOKEN
        raise TokenizerException, "Unknown token "+token.inspect
      end
      
      if tokenName && tokenName != nameOf(token)
        raise TokenizerException, "Unexpected token "+token.inspect
      end
      
      @historyPointer += 1
      
      # Advance cursor, line number, column
      
      tl = token.text.length
      @cursor += tl
      tl.times do |i|
        c = token.text[i]
        @column += 1
        if c == "\n"
          @lineNumber += 1
          @column = 0
        end
      end
      token
    end
    
    # Read next token if it has a particular name
    #
    # > tokenName : name to look for
    # < token read, or nil
    #
    def readIf(tokenName)
      ret = nil
      token = peek()
      if token && nameOf(token) == tokenName
        ret = read()
      end
      ret
    end
    
    # Read a sequence of tokens
    # @param seq string of space-delimited token names; if name is '_',
    #   allows any token name in that position
    # @return array of tokens read
    #
    def readSequence(seq)
      seqNames = seq.split(' ')
      ret = []
      seqNames.each do |name|
        tk = name != '_' ? read(name) : read
        ret.push(tk)
      end
      ret
    end

    # Read a sequence of tokens, if they have particular names
    # @param seq string of space-delimited token names; if name is '_',
    #   allows any token name in that position
    # @return array of tokens read, or nil if the tokens had different
    #   names (or an end of input was encountered)
    #
    def readSequenceIf(seq)
      ret = []
      seqNames = seq.split(' ')
      seqNames.each do |name|
        tk = peek
        break if !tk
        if name != '_' && nameOf(tk) != name
          break
        end
        ret.push(read)
      end
      
      if ret.size != seqNames.size
        unread(ret.size)
        ret = nil
      end
      ret
    end
    
    
    # Determine if another token exists
    #
    def hasNext
      !peek().nil?
    end
    
    # Get the name of a token 
    # (i.e., the name of the token definition, not its text)
    #
    # > token read from this tokenizer
    #
    def nameOf(token)
      @dfa.tokenName(token.id)
    end
    
    # Unread one (or more) previously read tokens
    # 
    # @raise TokenizerException if attempt to unread token that was never read
    #
    def unread(count = 1)
      if @historyPointer < count
        raise TokenizerException, "Cannot unread before start"
      end
      @historyPointer -= count
    end
    
  end
  
  
  # Tokens read by Tokenizer
  #
  class Token
    
    attr_reader :text, :lineNumber, :column, :id
    
    def initialize(id, text, lineNumber, column)
      @id = id
      @text = text
      @lineNumber = lineNumber
      @column = column
    end
    
    def unknown?
      id == ToknInternal::UNKNOWN_TOKEN
    end
    
    # Construct description of token location within text
    #
    def inspect
      s = "(line "+lineNumber.to_s+", col "+column.to_s+")"
      if !unknown?
        s = s.ljust(17) + " : " + text
      end
      s
    end
  end
  
  # Exception class for Tokenizer methods
  #
  class TokenizerException < Exception
  end

end # module Tokn
