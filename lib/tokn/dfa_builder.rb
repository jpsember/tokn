require 'tokn/range_partition'

module ToknInternal

  # Converts NFAs (nondeterministic, finite state automata) to
  # minimal DFAs.
  #
  # Performs the subset construction algorithm described in
  # (among other placess) http://en.wikipedia.org/wiki/Powerset_construction
  #
  # Also implements an innovative algorithm to partition a set of
  # edge labels into a set that has the property that no two elements
  # have overlapping regions.  This allows us to perform the subset construction
  # (and closure operations) efficiently while supporting large possible character
  # sets (e.g., unicode, which ranges from 0..0x10ffff.  See RangePartition.rb
  # for more details.
  #
  class DFABuilder

    # Convert an NFA to a DFA.
    #
    # @param startState the start state of the NFA
    #
    def self.nfa_to_dfa(startState)

      # Reverse this NFA, convert to DFA, then
      # reverse it, and convert it again.  Apparently this
      # produces a minimal DFA.

      rev = startState.reverseNFA

      bld = DFABuilder.new(rev)
      dfa = bld.build(true, false)  # partition, but don't normalize

      rev2 = dfa.reverseNFA()
      bld = DFABuilder.new(rev2)

      # Don't regenerate the partition; it is still valid
      # for this second build process
      #
      dfa = bld.build(false, true) # don't partition, but do normalize

      # If there are edges that contain more than one token identifier,
      # remove all but the first (i.e. the one with the highest token id)

      stSet, _, _ = dfa.reachableStates
      stSet.each do |s|
        s.edges.each do |lbl, dest|
          a = lbl.elements
          if a.size == 0
            next
          end

          primeId = a[0]

          next if primeId >= EPSILON-1

          lbl.difference!(CodeSet.new(primeId+1, EPSILON))
        end
      end
      dfa
    end

    # Constructs a builder object
    #
    def initialize(nfaStartState)
      @nextId = 0
      @nfaStart = nfaStartState

      # Build a map of nfa state ids => nfa states
      @nfaStateMap = {}
      nfas, _, _ = @nfaStart.reachableStates
      nfas.each {|s| @nfaStateMap[s.id] = s}

      # Initialize an array of nfa state lists, indexed by dfa state id
      @nfaStateLists = []

      # Map of existing DFA states; key is array of NFA state ids
      @dfaStateMap = {}
    end

    # Perform the build algorithm
    #
    # @param partition if true, partitions the edge labels into disjoint code sets
    # @param normalize if true, normalizes the states afterward
    #
    def build(partition = true, normalize = true)

      !partition || partitionEdges(@nfaStart)

      iset = Set.new
      iset.add(@nfaStart)
      epsClosure(iset)

      @dfaStart,_ = createDFAState(stateSetToIdArray(iset))

      unmarked = [@dfaStart]

      until unmarked.empty?
        dfaState  = unmarked.pop

        nfaIds = @nfaStateLists[dfaState.id]

        # map of CodeSet => set of NFA states
        moveMap = {}

        nfaIds.each do |nfaId|
          nfaState = @nfaStateMap[nfaId]
          nfaState.edges.each do |lbl,dest|
            if lbl.elements[0] == EPSILON
              next
            end

            nfaStates = moveMap[lbl]
            if nfaStates.nil?
              nfaStates = Set.new
              moveMap[lbl] = nfaStates
            end
            nfaStates.add(dest)
          end
        end

        moveMap.each_pair do |charRange,nfaStates|
          # May be better to test if already in set before calc closure; or simply has closure
          epsClosure(nfaStates)
          dfaDestState, isNew = createDFAState(stateSetToIdArray(nfaStates))
          if isNew
            unmarked.push(dfaDestState)
          end
          dfaState.addEdge(charRange, dfaDestState)
        end

      end

      if normalize
        State.normalizeStates(@dfaStart)
      end

      @dfaStart
    end

    private

    # Adds a DFA state for a set of NFA states, if one doesn't already exist
    # for the set
    # @param nfaStateList a sorted array of NFA state ids
    # @return a pair [DFA State,
    #                 created flag (boolean): true if this did not already exist]
    #
    def createDFAState(nfaStateList)

      lst = nfaStateList

      newState = @nfaStateMap[lst]
      isNewState = !newState
      if isNewState
        newState = State.new(@nextId)

        # Determine if any of the NFA states were final states
        newState.finalState = nfaStateList.any?{|id| @nfaStateMap[id].finalState?}

        if false
          warning "setting labels..."
          # Set label of DFA state to show which NFA states produced it
          # (useful for debugging)
          newState.label = lst.map {|x| x.to_s}.join(' ')
        end

        @nextId += 1
        @nfaStateMap[lst] = newState
        @nfaStateLists.push(lst)

      end
      return [newState,isNewState]
    end

    def stateSetToIdArray(s)
      s.to_a.map {|x| x.id}.sort
    end

    # Calculate the epsilon closure of a set of NFA states
    # @return a set of states
    #
    def epsClosure(stateSet)
      stk = stateSet.to_a
      while !stk.empty?
        s = stk.pop
        s.edges.each do |lbl,dest|
          if lbl.contains? EPSILON
            if stateSet.add?(dest)
              stk.push(dest)
            end
          end
        end
      end
      stateSet
    end

    # Modify edges so each is labelled with a disjoint subset
    # of characters.  See the notes at the start of this class,
    # as well as RangePartition.rb.
    #
    def partitionEdges(startState)

      par = RangePartition.new

      stateSet, _, _ = startState.reachableStates

      stateSet.each do |s|
        s.edges.each {|lbl,dest| par.addSet(lbl) }
      end

      par.prepare

      stateSet.each do |s|
        newEdges = []
        s.edges.each do |lbl, dest|
          newLbls = par.apply(lbl)
          newLbls.each {|x| newEdges.push([x, dest]) }
        end
        s.clearEdges()

        newEdges.each do |lbl,dest|
          s.addEdge(lbl,dest)
        end
      end

    end


  end

end  # module ToknInternal
