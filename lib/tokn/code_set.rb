require_relative 'tools'

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
      @elem = []
      if lower
        add(lower,upper)
      end
    end
    
    # Replace this set with a copy of another
    #
    def setTo(otherSet)
      @elem.replace(otherSet.array)  
    end
    
    # Get the array containing the code set range pairs
    #
    def array
      @elem
    end
    
    # Replace this set's array
    # @param a array to point to (does not make a copy of it)
    #
    def setArray(a)
      @elem = a
    end
  
    # Get hash code; just uses hash code of the contained array
    def hash
      @elem.hash
    end
  
    # Determine if this set is equivalent to another, by
    # comparing the contained arrays
    #
    def eql?(other)
      @elem == other.array
    end
  
  
    # Add a contiguous range of values to the set
    # @param lower min value in range
    # @param upper one plus max value in range
    #
    def add(lower, upper = nil)
      if not upper
        upper = lower + 1
      end
      
      if lower >= upper
        raise RangeError
      end
      
      newSet = [] 
      i = 0
      while i < @elem.size and @elem[i] < lower
        newSet.push(@elem[i])
        i += 1
      end 
      
      if (i & 1) == 0
        newSet.push(lower)
      end
      
      while i < @elem.size and @elem[i] <= upper
        i += 1
      end
      
      if (i & 1) == 0
        newSet.push(upper)
      end
      
      while i < @elem.size 
        newSet.push(@elem[i])
        i += 1
      end
      
      @elem = newSet
      
    end
  
  
    # Remove a contiguous range of values from the set
    # @param lower min value in range
    # @param upper one plus max value in range
    #
    def remove(lower, upper = nil)
      if not upper
        upper = lower + 1
      end
      
      if lower >= upper
        raise RangeError
      end
      
      newSet = [] 
      i = 0
      while i < @elem.size and @elem[i] < lower
        newSet.push(@elem[i])
        i += 1
      end 
      
      if (i & 1) == 1
        newSet.push(lower)
      end
      
      while i < @elem.size and @elem[i] <= upper
        i += 1
      end
      
      if (i & 1) == 1
        newSet.push(upper)
      end
      
      while i < @elem.size 
        newSet.push(@elem[i])
        i += 1
      end
      
      setArray(newSet)
      
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
      sa = s.array
      
      (0 ... sa.length).step(2) {
        |i| add(sa[i],sa[i+1])
      }
    end
    
    # Determine if this set contains a particular value
    def contains?(val)
      ret = false
      i = 0
      while i < @elem.size
        if val < @elem[i]
          break
        end 
        if val < @elem[i+1]
          ret = true
          break
        end
        i += 2
      end  
      
      ret
      
    end
    
    # Get string representation of set, treating them (where
    # possible) as printable ASCII characters
    #
    def to_s
      s = ''
      i = 0
      while i < @elem.size
        if s.size
          s += ' '
        end
        
        lower = @elem[i]
        upper = @elem[i+1]
        s += dbStr(lower)
        if upper != 1+lower
          s += '..' + dbStr(upper-1)
        end
        i += 2
      end
      return s
    end
    
    # Calls to_s
    def inspect
      to_s
    end
    
    # Get string representation of set, treating them
    # as integers
    #
    def to_s_alt
      s = ''
      i = 0
      while i < @elem.size
        if s.length > 0
          s += ' '
        end
        low = @elem[i]
        upr = @elem[i+1]
        s += low.to_s
        if upr > low+1
          s += '..'
          s += (upr-1).to_s
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
      s2 = CodeSet.new(lower,upper)
      if lower >= upper
        raise RangeError
      end
      
      newSet = [] 
      i = 0
      while i < @elem.size and @elem[i] <= lower
        newSet.push(@elem[i])
        i += 1
      end 
      
      if i > 0 and newSet[i-1] == lower
        newSet.pop
      else
        newSet.push(lower)
      end
      
      while i < @elem.size and @elem[i] <= upper
        newSet.push(@elem[i])
        i += 1
      end 
      
      
      if newSet.length > 0 and newSet.last == upper
        newSet.pop
      else
        newSet.push(upper)
      end
      
      while i < @elem.size 
        newSet.push(@elem[i])
        i += 1
      end 
      
      @elem = newSet
      
    end
    
    # Determine how many distinct values are represented by this set
    def cardinality
      c = 0
      i = 0
      while i < @elem.length
        c += @elem[i+1] - @elem[i]
        i += 2
      end
      c
    end
    
    # Determine if this set is empty
    #
    def empty?
      @elem.empty?
    end
    
    private
    
    # Get a debug description of a value within a CodeSet, suitable
    # for including within a .dot label
    #
    def dbStr(charCode)
      
      # Unless it corresponds to a non-confusing printable ASCII value,
      # just print its decimal equivalent
      
      s = charCode.to_s
      
      if charCode == EPSILON
        s = "(e)"
      elsif (charCode > 32 && charCode < 0x7f && !"'\"\\[]{}()".index(charCode.chr))
        s = charCode.chr
      end  
      return s
    end
  
    # Combine this range (a) with another (b) according to particular operation 
    # > s  other range (b)
    # > oper   'i': intersection, a^b
    #          'd': difference, a-b
    #          'n': negation, (a & !b) | (!a & b)
    # 
    def combineWith(s, oper)
      sa = array
      sb = s.array
      
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
      ret.setArray(c)
      ret
    end
  
  end

end