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
              if a[0] < ToknInternal::EPSILON
                newTokenId = ToknInternal::edgeLabelToTokenId(a[0])

                if (bestLength < charOffset || newTokenId > bestId)
                  bestLength, bestId = charOffset, newTokenId
                end
              end

              if ch && lbl.contains?(ch)
                nextState = dest
                break
              end
            end

            if !nextState
              break
            end
            state = nextState
            charOffset += 1
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
      raise TokenizerException,"No more tokens" if !token
      raise TokenizerException, "Unknown token #{token}" if token.id == ToknInternal::UNKNOWN_TOKEN
      raise TokenizerException, "Unexpected token #{token}" if tokenName && tokenName != nameOf(token)

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


end # module Tokn
