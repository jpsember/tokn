module Tokn
  # Tokens read by Tokenizer
  #
  class Token

    attr_reader :text, :line_number, :column, :id

    def initialize(id, text, line_number, column)
      @id = id
      @text = text
      @line_number = line_number
      @column = column
    end

    def unknown?
      id == ToknInternal::UNKNOWN_TOKEN
    end

    def to_s
      s = "(line #{line_number}, col #{column})"
      s = s.ljust(17) << ' : ' << text
      s
    end

  end
end

