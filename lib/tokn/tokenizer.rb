module Tokn

HISTORY_CAPACITY = 16

class TokenizerException < Exception; end

# Extracts tokens from a script, given a previously constructed DFA.
#
class Tokenizer

  attr_accessor :accept_unknown_tokens

  # Construct a tokenizer
  #
  # @param dfa the DFA to use
  # @param string_or_io a string or file to extract tokens from
  # @param skip_name if not nil, tokens with this name will be skipped
  #
  def initialize(dfa, string_or_io, skip_name=nil)
    @accept_unknown_tokens = false
    @dfa = dfa

    @skip_token_id = nil
    if skip_name
      @skip_token_id = dfa.token_id(skip_name) or raise ArgumentError, "No token with name #{skip_name} found"
    end
    @line_number = 0
    @column = 0

    # Token buffer to support peeking / unreading
    #
    @token_history = []

    # Index within token_history of token to be returned by read() method
    #
    @history_cursor = 0

    prepare_input(string_or_io)
  end


  # Determine next token (without reading it)
  #
  # Returns Token, or nil if end of input
  #
  def peek

    # If token isn't in the history buffer, read and place it there
    if @history_cursor == @token_history.size

      # repeat until we find a non-skipped token, or run out of text
      while true

        token = peek_aux
        break if token.nil?

        if token.id == @skip_token_id
          advance_cursor_for_token_text(token.text)
        else
          add_token_to_history(token)
          break # We found a token, so stop
        end
      end
    end

    # If token is within history buffer, return it; else, nil (no tokens remain)
    #
    ret = nil
    if @history_cursor < @token_history.size
      ret = @token_history[@history_cursor]
    end

    ret
  end

  def peek_aux

    # If no characters remain, return nil
    return nil if !peek_char(0)

    # Default to an unknown token of a single character
    best_length = 1
    best_id = ToknInternal::UNKNOWN_TOKEN

    char_offset = 0
    state = @dfa.start_state

    while true

      next_char_integer = -1
      next_char = peek_char(char_offset)
      if next_char
        next_char_integer = next_char.ord
      end

      # Examine edges leaving this state.
      # If one is labelled with a token id, we don't need to match the character with it;
      # store as best token found if id is not less than previous best.

      # If an edge is labelled with the current character, advance to that state.

      next_state = nil
      state.edges.each do |edge_label,dest_state|

        # If edge points to a final state, its label will correspond to a single token id;
        # otherwise, its label contains a set of nonnegative character codes

        if dest_state.final_state
          token_id = ToknInternal::edge_label_to_token_id(edge_label.elements[0])

          if token_id >= best_id || char_offset > best_length
            best_length, best_id = char_offset, token_id
          end
        elsif edge_label.contains?(next_char_integer)
          next_state = dest_state
        end
      end

      break if !next_state
      state = next_state
      char_offset += 1
    end

    best_text = skip_chars(best_length)
    Token.new(best_id, best_text, 1 + @line_number, 1 + @column)
  end

  def advance_cursor_for_token_text(text)
    text.length.times do |i|
      c = text[i]
      @column += 1
      if c == "\n"
        @line_number += 1
        @column = 0
      end
    end
  end

  # Read next token
  #
  # @param token_name_or_id  if not nil, the name or id of the expected token
  #
  # @raise TokenizerException if no more tokens,if unrecognized token, or
  #    if token was different than expected
  #
  def read(token_name_or_id = nil)

    # Peek at token first, to place it within the history buffer
    #
    token = peek
    raise TokenizerException,"No more tokens" if token.nil?
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

    # Advance history cursor to make token read
    #
    @history_cursor += 1

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
  def unread(count = 1)
    if [@history_cursor,HISTORY_CAPACITY].min < count
      raise TokenizerException, "Token unavailable"
    end
    @history_cursor -= count
  end


  private


  def prepare_input(string_or_io)
    if string_or_io.is_a? String
      require 'stringio'
      @input = StringIO.new(string_or_io)
    else
      @input = string_or_io
    end
    @char_buffer = ""
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

    # Trim history buffer every so often if it's getting full;
    # retain O(1) amortized performance

    if @token_history.size >= HISTORY_CAPACITY * 2
      remove_total = HISTORY_CAPACITY
      @token_history.slice!(0...remove_total)
      @history_cursor -= remove_total
    end
  end

end # class

end # module Tokn
