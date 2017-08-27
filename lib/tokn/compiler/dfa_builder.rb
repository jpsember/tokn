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

    attr_reader :start_state
    attr_accessor :with_filter
    attr_accessor :generate_pdf

    def initialize(start_state)
      @start_state = start_state
      @with_filter = true
      @generate_pdf = false
    end

    # Convert an NFA to a DFA; return the new start state
    #
    def nfa_to_dfa

      partition_edges
      minimize

      @start_state.generate_pdf("_SKIP_prefilter.pdf") if @generate_pdf

      if @with_filter
        filter = Filter.new(@start_state)
        filter.verbose = @generate_pdf
        filter.apply
        if filter.modified
          # Re-minimize the dfa, since it's been modified by the filter
          minimize
          @start_state.generate_pdf("_SKIP_postfilter.pdf") if @generate_pdf
        end
      end

      @start_state
    end


    private


    # Construct minimized dfa from nfa
    #
    def minimize
      # Reverse this NFA, convert to DFA, then
      # reverse it, and convert it again.  Apparently this
      # produces a minimal DFA.

      @start_state = @start_state.reverseNFA
      nfa_to_dfa_aux

      @start_state = @start_state.reverseNFA
      nfa_to_dfa_aux

      State.normalizeStates(@start_state)
    end

    # Perform the build algorithm
    #
    def nfa_to_dfa_aux
      @nextId = 0

      # Build a map of nfa state ids => nfa states
      @nfaStateMap = {}
      nfas, _, _ = start_state.reachableStates
      nfas.each {|s| @nfaStateMap[s.id] = s}

      # Initialize an array of nfa state lists, indexed by dfa state id
      @sorted_nfa_state_id_lists = []

      # Map of existing DFA states; key is array of NFA state ids
      @dfaStateMap = {}

      iset = Set.new
      iset.add(start_state)
      eps_closure(iset)

      new_start_state,_ = create_dfa_state_if_necessary(states_to_sorted_ids(iset))

      unmarked = [new_start_state]

      until unmarked.empty?
        dfaState  = unmarked.pop

        nfaIds = @sorted_nfa_state_id_lists[dfaState.id]

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
          eps_closure(nfaStates)
          dfaDestState, isNew = create_dfa_state_if_necessary(states_to_sorted_ids(nfaStates))
          if isNew
            unmarked.push(dfaDestState)
          end
          dfaState.addEdge(charRange, dfaDestState)
        end

      end

      @start_state = new_start_state
    end

    # Modify edges so each is labelled with a disjoint subset
    # of characters.  See the notes at the start of this class,
    # as well as RangePartition.rb.
    #
    def partition_edges

      par = RangePartition.new

      stateSet, _, _ = @start_state.reachableStates

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

    # Adds a DFA state for a set of NFA states, if one doesn't already exist
    # for the set
    #
    # @param sorted_nfa_state_id_list a sorted array of NFA state ids
    # @return a pair [DFA State,
    #                 created flag (boolean): true if this did not already exist]
    #
    def create_dfa_state_if_necessary(sorted_nfa_state_id_list)
      newState = @nfaStateMap[sorted_nfa_state_id_list]
      isNewState = newState.nil?
      if isNewState
        newState = State.new(@nextId)

        # Determine if any of the NFA states were final states
        newState.final_state = sorted_nfa_state_id_list.any?{|id| @nfaStateMap[id].final_state}

        @nextId += 1
        @nfaStateMap[sorted_nfa_state_id_list] = newState
        @sorted_nfa_state_id_lists.push(sorted_nfa_state_id_list)
      end
      return [newState,isNewState]
    end

    def states_to_sorted_ids(s)
      s.to_a.map {|x| x.id}.sort
    end

    # Calculate the epsilon closure of a set of NFA states
    #
    def eps_closure(stateSet)
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
    end

  end # class DFABuilder

end  # module ToknInternal
