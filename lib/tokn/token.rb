module Tokn
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

    def to_s
      s = "(line #{lineNumber}, col #{column})"
      if !unknown?
        s = s.ljust(17) << ' : ' << text
      end
      s
    end

  end
end

