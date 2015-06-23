module ToknInternal

  # A CodeSet is an ordered set of character or token codes that
  # are used as labels on DFA edges.
  #
  # In addition to unicode character codes 0...0x10ffff, they
  # also represent epsilon transitions (-1), or token identifiers ( < -1).
  #
  # Each CodeSet is represented as an array with 2n elements;
  # each pair represents a closed lower and open upper range of values.
  #
  # Thus a value x is within the set [a1,a2,b1,b2,..]
  # iff (a1 <= x < a2) or (b1 <= x < b2) or ...
  #
  class CodeSet

    attr_accessor :elements

    # Construct a copy of this set
    #
    def makeCopy
      c = CodeSet.new
      c.setTo(self)
      c
    end

    # Initialize set; optionally add an initial contiguous range
    #
    def initialize(lower = nil, upper = nil)
      @elements = []
      if lower
        add(lower,upper)
      end
    end

    # Replace this set with a copy of another
    #
    def setTo(otherSet)
      @elements.replace(otherSet.elements)
    end

    # Get hash code; just uses hash code of the contained array
    def hash
      @elements.hash
    end

    # Determine if this set is equivalent to another, by
    # comparing the contained arrays
    #
    def eql?(other)
      @elements == other.elements
    end

    # Add a contiguous range of values to the set
    # @param lower min value in range
    # @param upper one plus max value in range
    #
    def add(lower, upper = nil)
      if not upper
        upper = lower + 1
      end

      raise RangeError if lower >= upper

      newSet = []
      i = 0
      while i < @elements.size and @elements[i] < lower
        newSet << @elements[i]
        i += 1
      end

      if (i & 1) == 0
        newSet << lower
      end

      while i < @elements.size and @elements[i] <= upper
        i += 1
      end

      if (i & 1) == 0
        newSet << upper
      end

      while i < @elements.size
        newSet << @elements[i]
        i += 1
      end

      @elements = newSet

    end

    # Remove a contiguous range of values from the set
    # @param lower min value in range
    # @param upper one plus max value in range
    #
    def remove(lower, upper = nil)
      if upper.nil?
        upper = lower + 1
      end

      if lower >= upper
        raise RangeError
      end

      newSet = []
      i = 0
      while i < @elements.size and @elements[i] < lower
        newSet << @elements[i]
        i += 1
      end

      if (i & 1) == 1
        newSet << lower
      end

      while i < @elements.size and @elements[i] <= upper
        i += 1
      end

      if (i & 1) == 1
        newSet << upper
      end

      while i < @elements.size
        newSet << @elements[i]
        i += 1
      end

      @elements = newSet
    end

    # Replace this set with itself minus another
    #
    def difference!(s)
      setTo(difference(s))
    end

    # Calculate difference of this set minus another
    def difference(s)
      combineWith(s, 'd')
    end

    # Calculate the intersection of this set and another
    def intersect(s)
      combineWith(s, 'i')
    end

    # Set this set equal to its intersection with another
    def intersect!(s)
      setTo(intersect(s))
    end

    # Add every value from another CodeSet to this one
    def addSet(s)
      sa = s.elements
      (0...sa.length).step(2){|i| add(sa[i],sa[i+1]) }
    end

    # Determine if this set contains a particular value
    def contains?(val)
      i = 0
      while i < @elements.size
        return false if val < @elements[i]
        return true if val < @elements[i+1]
        i += 2
      end
      false
    end

    # Get string representation of set, treating them (where
    # possible) as printable ASCII characters
    #
    def to_s
      s = ''
      i = 0
      while i < @elements.size
        if s.size
          s += ' '
        end

        lower = @elements[i]
        upper = @elements[i+1]
        s += CodeSet.dbStr(lower)
        if upper != 1+lower
          s += '..' + CodeSet.dbStr(upper-1)
        end
        i += 2
      end
      return s
    end

    # Negate the inclusion of a contiguous range of values
    #
    # @param lower min value in range
    # @param upper one plus max value in range
    #
    def negate(lower = 0, upper =  CODEMAX)
      if lower >= upper
        raise RangeError
      end

      newSet = []
      i = 0
      while i < @elements.size and @elements[i] <= lower
        newSet << @elements[i]
        i += 1
      end

      if i > 0 and newSet[i-1] == lower
        newSet.pop
      else
        newSet << lower
      end

      while i < @elements.size and @elements[i] <= upper
        newSet << @elements[i]
        i += 1
      end


      if newSet.length > 0 and newSet.last == upper
        newSet.pop
      else
        newSet << upper
      end

      while i < @elements.size
        newSet << @elements[i]
        i += 1
      end

      @elements = newSet

    end

    # Determine how many distinct values are represented by this set
    def cardinality
      c = 0
      i = 0
      while i < @elements.length
        c += @elements[i+1] - @elements[i]
        i += 2
      end
      c
    end

    # Determine if this set is empty
    #
    def empty?
      @elements.empty?
    end


    private


    # Get a debug description of a value within a CodeSet, suitable
    # for including within a .dot label
    #
    def self.dbStr(charCode)
      # Unless it corresponds to a non-confusing printable ASCII value,
      # just print its decimal equivalent
      s = charCode.to_s
      if charCode == EPSILON
        s = "(e)"
      elsif (charCode > 32 && charCode < 0x7f && !"'\"\\[]{}()".index(charCode.chr))
        s = charCode.chr
      elsif charCode == CODEMAX-1
        s = "MAX"
      end
      s
    end

    # Combine this range (a) with another (b) according to particular operation
    # > s  other range (b)
    # > oper   'i': intersection, a^b
    #          'd': difference, a-b
    #          'n': negation, (a & !b) | (!a & b)
    #
    def combineWith(s, oper)
      sa = elements
      sb = s.elements

      i = 0
      j = 0
      c = []

      wasInside = false

      while i < sa.length || j < sb.length

        if i == sa.length
          v = sb[j]
        elsif j == sb.length
          v = sa[i]
        else
          v = [sa[i],sb[j]].min
        end

        if i < sa.length && v == sa[i]
          i += 1
        end
        if j < sb.length && v == sb[j]
          j += 1
        end

        case oper
        when 'i'
          inside = ((i & 1) == 1) && ((j & 1) == 1)
        when 'd'
          inside = ((i & 1) == 1) && ((j & 1) == 0)
        else
          raise Exception, "illegal"
        end

        if inside != wasInside
          c.push v
          wasInside = inside
        end
      end
      ret = CodeSet.new()
      ret.elements = c
      ret
    end

  end

end
