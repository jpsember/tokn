module Tokn

# Extracts tokens from a script, given a previously constructed DFA.
#
class Tokenizer

  attr_accessor :accept_unknown_tokens

  # Construct a tokenizer
  #
  # @param dfa the DFA to use
  # @param string_or_io a string or file to extract tokens from
  # @param skipName if not nil, tokens with this name will be skipped
  # @param maximum_history_size the maximum number of tokens that can be unread
  #
  def initialize(dfa, string_or_io, skipName=nil, maximum_history_size=16)
    @dfa = dfa
    raise ArgumentError if !string_or_io

    @skipTokenId = nil
    if skipName
      @skipTokenId = dfa.tokenId(skipName)
      if !@skipTokenId
        raise ArgumentError, "No token with name "+skipName+" found"
      end
    end
    @lineNumber = 0
    @column = 0
    @token_history = []
    @history_pointer = 0
    @maximum_history_size = maximum_history_size
    @history_slack = 100
    @accept_unknown_tokens = false

    prepare_input(string_or_io)
  end


  # Determine next token (without reading it)
  #
  # Returns Token, or nil if end of input
  #
  def peek

    v = false

    if @history_pointer == @token_history.size
      puts "...peeking for next token" if v
      while true # repeat until we find a non-skipped token, or run out of text
        break if !peek_char(0)

        bestLength = 1
        bestId = ToknInternal::UNKNOWN_TOKEN

        charOffset = 0
        state = @dfa.startState
        while true
          ch = 0
          next_char = peek_char(charOffset)
          puts " state:#{state.name} next char: #{next_char}" if v
          ch = next_char.ord if next_char

          nextState = nil

          # Examine edges leaving this state.
          # If one is labelled with a token id, we don't need to match the character with it;
          # store as best token found if length is longer than previous, or equal to previous
          # with higher id.

          # If an edge is labelled with the current character, advance to that state.

          edges = state.edges
          edges.each do |lbl,dest|
            a = lbl.elements
            puts "   label: #{lbl} elements:#{a}" if v
            if a[0] < ToknInternal::EPSILON
              newTokenId = ToknInternal::edge_label_to_token_id(a[0])
              #puts "    token id: #{newTokenId} length: #{charOffset}" if v

              # We don't want a longer, lower-valued token overriding a higher-valued one
              if (newTokenId > bestId || (newTokenId == bestId && charOffset > bestLength))
                bestLength, bestId = charOffset, newTokenId
                puts "    new best length: #{bestLength} id: #{bestId}" if v
              end
            end

            if ch && lbl.contains?(ch)
              nextState = dest
            end
          end

          break if !nextState || !ch
          state = nextState
          charOffset += 1
        end

        best_text = skip_chars(bestLength)

        if bestId == @skipTokenId
          advance_cursor_for_token_text(best_text)
          next
        end

        peekToken = Token.new(bestId, best_text, 1 + @lineNumber, 1 + @column)

        add_token_to_history(peekToken)
        break # We found a token, so stop
      end
    end

    ret = nil
    if @history_pointer < @token_history.size
      ret = @token_history[@history_pointer]
    end

    ret
  end

  def advance_cursor_for_token_text(text)
    text.length.times do |i|
      c = text[i]
      @column += 1
      if c == "\n"
        @lineNumber += 1
        @column = 0
      end
    end
  end

  # Read next token
  #
  # @param tokenName  if not nil, the (string) name of the token expected
  #
  # @raise TokenizerException if no more tokens,if unrecognized token, or
  # if token has different than expected name
  #
  def read(token_name_or_id = nil)
    token = peek()
    raise TokenizerException,"No more tokens" if !token
    raise TokenizerException,"Unknown token #{token}" if !accept_unknown_tokens && token.unknown?
    if token_name_or_id
      unexpected = false
      if token_name_or_id.is_a? String
        unexpected = token_name_or_id != name_of(token)
      else
        unexpected = token_name_or_id != token.id
      end
      raise TokenizerException, "Unexpected token #{token}" if unexpected
    end

    @history_pointer += 1

    advance_cursor_for_token_text(token.text)
    token
  end

  # Read next token if it has a particular name or id; return nil if otherwise
  #
  def read_if(token_name_or_id)
    ret = nil
    token = peek()
    read_it = false
    if token
      if token_name_or_id.is_a? String
        read_it = token_name_or_id == name_of(token)
      else
        read_it = token_name_or_id == token.id
      end
    end
    if read_it
      ret = read
    end
    ret
  end

  # Read a sequence of tokens
  # @param seq array of ids, or a string of space-delimited token names;
  #   if name is '_', or id is nil,
  #   allows any token name in that position
  # @return array of tokens read
  #
  def read_sequence(seq)
    names = seq.is_a? String
    if names
      seq = seq.split(' ')
    end
    ret = []
    seq.each do |name_or_id|
      ret << read(name_or_id)
    end
    ret
  end

  # Read a sequence of tokens, if they have particular names or ids
  # @param seq array of ids, or a string of space-delimited token names;
  #   if name is '_', or id is nil,
  #   allows any token name in that position
  # @return array of tokens read, or nil if the tokens had different
  #   names (or an end of input was encountered)
  #
  def read_sequence_if(seq)
    ret = []
    names = seq.is_a? String
    if names
      seq = seq.split(' ')
    end
    seq.each do |name_or_id|
      # Accept any token if wildcard
      if name_or_id == '_' || !name_or_id
        tk = nil
        if peek
          tk = read
        end
      else
        tk = read_if(name_or_id)
      end
      break if !tk
      ret << tk
    end

    if ret.size != seq.size
      unread(ret.size)
      ret = nil
    end
    ret
  end


  # Determine if another token exists
  #
  def has_next
    !peek().nil?
  end

  # Get the name of a token
  # (i.e., the name of the token definition, not its text)
  #
  # > token read from this tokenizer
  #
  def name_of(token)
    @dfa.token_name(token.id)
  end

  # Unread one (or more) previously read tokens
  #
  # @raise TokenizerException if token is no longer in the history
  #
  def unread(count = 1)
    if @history_pointer < count
      raise TokenizerException, "Token unavailable"
    end
    @history_pointer -= count
  end


  private


  def prepare_input(string_or_io)
    if string_or_io.is_a? String
      require 'stringio'
      @input = StringIO.new(string_or_io)
    else
      @input = string_or_io
    end
    @char_buffer = ''
  end

  def peek_char(index)
    ret = nil
    if index < @char_buffer.size
      ret = @char_buffer[index]
    else
      # Attempt to read more chars into buffer
      str = @input.read(256)
      @char_buffer << str if str
      if index < @char_buffer.size
        ret = @char_buffer[index]
      end
    end
    ret
  end

  def skip_chars(count)
    raise ArgumentError if count > @char_buffer.size
    @char_buffer.slice!(0...count)
  end

  def add_token_to_history(token)
    @token_history << token
    if @token_history.size > @maximum_history_size + @history_slack
      @token_history.slice!(0...@history_slack)
      @history_pointer -= @history_slack
    end
  end

end # class

end # module Tokn
