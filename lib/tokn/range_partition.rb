module ToknInternal

  # A data structure that transforms a set of CodeSets to a
  # disjoint set of them, such that no two range sets overlap.
  #
  # This is to improve the efficiency of the NFA => DFA algorithm,
  # which involves gathering information about what states are
  # reachable on certain characters.  We can't afford to treat each
  # character as a singleton, since the ranges can be quite large.
  # Hence, we want to treat ranges of characters as single entities;
  # this will only work if no two such ranges overlap.
  #
  # It works by starting with a tree whose node is labelled with
  # the maximal superset of character values.  Then, for each edge
  # in the NFA, performs a DFS on this tree, splitting any node that
  # only partially intersects any one set that appears in the edge label.
  # The running time is O(n log k), where n is the size of the NFA, and
  # k is the height of the resulting tree.
  #
  # We encourage k to be small by sorting the NFA edges by their
  # label complexity.
  #
  class RangePartition

    def initialize()
      # We will build a tree, where each node has a CodeSet
      # associated with it, and the child nodes (if present)
      # partition this CodeSet into smaller, nonempty sets.

      # A tree is represented by a node, where each node is a pair [x,y],
      # with x the node's CodeSet, and y a list of the node's children.

      @nextNodeId = 0
      @prepared = false

      # Make the root node hold the largest possible CodeSet.
      # We want to be able to include all the token ids as well.

      @rootNode = buildNode(CodeSet.new(CODEMIN,CODEMAX))

      @setsToAdd = Set.new

      # Add epsilon immediately, so it's always in its own subset
      addSet(CodeSet.new(EPSILON))
    end

    def addSet(s)
      if @prepared
        raise IllegalStateException
      end
      @setsToAdd.add(s)
    end

    def prepare()
      if @prepared
        raise IllegalStateException
      end

      # Construct partition from previously added sets

      list = @setsToAdd.to_a

      # Sort set by cardinality: probably get a more balanced tree
      # if larger sets are processed first
      list.sort!{ |x,y| y.cardinality <=> x.cardinality }

      list.each do |s|
        addSetAux(s)
      end

      @prepared = true
    end


    # Apply the partition to a CodeSet
    #
    # > s CodeSet
    # < array of subsets from the partition whose union equals s
    #   (this array will be the single element s if no partitioning was necessary)
    #
    def apply(s)
      if !@prepared
        raise IllegalStateException
      end

      list = []
      s2 = s.makeCopy
      applyAux(@rootNode, s2, list)

      # Sort the list of subsets by their first elements
      list.sort{ |x,y| x.elements[0] <=> y.elements[0] }
    end


    private

    def applyAux(n, s, list)

      if n.children.empty?
        # # Verify that this set equals the input set
        # myAssert(s.eql? n.set)
        list.push(s)
      else
        n.children.each do |m|
          s1 = s.intersect(m.set)

          if s1.empty?
            next
          end

          applyAux(m, s1, list)

          s = s.difference(m.set)
          if s.empty?
            break
          end
        end
      end
    end

    def buildNode(rangeSet)
      id = @nextNodeId
      @nextNodeId += 1
      n = RPNode.new(id, rangeSet, [])
      n
    end

    def buildNodeList(list, root = nil)
      if not root
        root = @rootNode
      end
      list.push(root)
      root.children.each do |x|
        buildNodeList(list, x)
      end
    end

    # Add a set to the tree, extending the tree as necessary to
    # maintain a (disjoint) partition
    #
    def addSetAux(s, n = @rootNode)
      #
      # The algorithm is this:
      #
      # add (s, n)    # add set s to node n; s must be subset of n.set
      #   if n.set = s, return
      #   if n is leaf:
      #     x = n.set - s
      #     add x,y as child sets of n
      #   else
      #     for each child m of n:
      #       t = intersect of m.set and s
      #       if t is nonempty, add(t, m)
      #
      if n.set.eql? s
        return
      end
      if n.children.empty?
        x = n.set.difference(s)
        n.children.push buildNode(x)
        n.children.push buildNode(s)
      else
        n.children.each do |m|
          t = m.set.intersect(s)
          addSetAux(t,m) unless t.empty?
        end
      end
    end

  end

  # A node within a RangePartition tree
  #
  class RPNode

    attr_accessor :id, :set, :children

    def initialize(id, set, children)
      @id = id
      @set = set
      @children = children
    end

    def to_s
      "N#{id}"
    end
  end

end  # module ToknInternal

