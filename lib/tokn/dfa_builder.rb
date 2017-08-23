require_relative 'range_partition'

module ToknInternal

  EXP = false

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
    def self.nfa_to_dfa(start_state, apply_filter = true)

      partitionEdges(start_state)

      start_state = self.minimize(start_state)

      start_state.generate_pdf("_SKIP_prefilter.pdf") if EXP

      start_state.generate_pdf("_SKIP_prefilter.pdf") if EXP

      if apply_filter
        filter = Filter.new
        filter.apply(start_state)
        if filter.modified
          # Re-minimize the dfa, since it's been modified by the filter
          start_state = self.minimize(start_state)
          start_state.generate_pdf("_SKIP_postfilter.pdf") if EXP
        end
      end

      raise "aborting for experiment" if EXP

      start_state
    end

    def self.minimize(nfa_start_state)
      # Reverse this NFA, convert to DFA, then
      # reverse it, and convert it again.  Apparently this
      # produces a minimal DFA.

      start_state = nfa_start_state
      start_state = start_state.reverseNFA
      start_state = build_dfa_from_nfa(start_state)

      start_state = start_state.reverseNFA
      start_state = build_dfa_from_nfa(start_state)

      State.normalizeStates(start_state)
      start_state
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
    def build

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
      @dfaStart
    end

    private

    def self.build_dfa_from_nfa(start_state)
      bld = DFABuilder.new(start_state)
      bld.build
    end

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
    def self.partitionEdges(startState)

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

  end # class DFABuilder



  class Filter

    attr_reader :modified

    def node_value(state)
      value = @node_values[state.id]
      if value.nil?
        state.edges.each do |lbl, dest|
          next unless dest.finalState
          puts "....calculating value for state from edge: #{lbl.elements}" if EXP
          a = lbl.elements
          primeId = a[0]
          value = ToknInternal::edge_label_to_token_id(primeId)
        end
        if value.nil?
          value = -1
        end
        @node_values[state.id] = value
      end
      value
    end

    def marker_value_for(state)
      @node_markers[state.id]
    end

    def store_marker_value(state, marker_value)
      old_marker_value = @node_markers[state.id]
      if old_marker_value.nil? || (old_marker_value < marker_value)
        puts "         (updating marker value for #{state.name} to: #{marker_value})" if EXP
        @node_markers[state.id] = marker_value
      end
    end

    def apply(start_state)

      if EXP
        puts
        puts "============== apply useless edge filter"
        puts
      end

      @start_state = start_state
      @modified = false
      state_ids_processed = Set.new
      @state_list = []

      @node_markers = {}
      @node_values = {}
      @node_markers[start_state.id] = node_value(start_state)

      queue = [start_state]
      state_ids_processed.add(start_state.id)

      while !queue.empty?
        state = queue.shift
        puts "...popped state: #{state.name}" if EXP
        @state_list << state

        marker_value = marker_value_for(state)
        state_value = node_value(state)
        if !marker_value.nil?
          marker_value = [marker_value, state_value].max
        else
          marker_value = state_value
        end

        puts "    marker: #{marker_value_for(state)} state:#{state_value} max:#{marker_value}" if EXP

        state.edges.each do |lbl, dest|
          next if dest.finalState
          puts "    edge to: #{dest.name}" if EXP
          dest_value = node_value(dest)
          puts "     value: #{dest_value}" if EXP

          dest_marker_value = marker_value_for(dest)
          if dest_marker_value.nil?
            dest_marker_value = marker_value
          end
          dest_marker_value = [dest_marker_value, marker_value].min
          dest_marker_value = [dest_marker_value, dest_value].max

          store_marker_value(dest, dest_marker_value)

          if !state_ids_processed.include?(dest.id)
            state_ids_processed.add(dest.id)
            queue << dest
          end
        end
      end

      puts start_state.describe_state_machine if EXP
      #remove_useless_edges
      filter_multiple_tokens_within_edge
      disallow_zero_length_tokens
    end

    def disallow_zero_length_tokens
      @start_state.edges.each do |lbl, dest|
        if dest.finalState
          raise "DFA recognizes zero-length tokens!"
        end
      end
    end

    def remove_useless_edges
      @state_list.each do |state|

        remove_list = []
        state.edges.each_with_index do |edge,edge_index|
          _, dest = edge
          next if dest.finalState

          source_marker_value = marker_value_for(state)
          dest_marker_value = marker_value_for(dest)

          next unless source_marker_value > dest_marker_value

          puts " source marker value #{state.name}:#{source_marker_value} exceeds dest marker value #{dest.name}:#{dest_marker_value}" if EXP
          remove_list << edge_index
        end

        next if remove_list.empty?

        @modified = true

        # Remove the useless edges in reverse order, since indices change as we remove them
        remove_list.reverse.each { |x| state.remove_edge(x)}

      end
    end

    def filter_multiple_tokens_within_edge
      @state_list.each do |state|
        state.edges.each do |lbl, dest|
          next unless dest.finalState
          a = lbl.elements
          primeId = a[0]

          raise "expected token definitions on transition to final state" if primeId >= EPSILON

          exp = primeId + 1

          if a[1] != exp
            puts "...removing multiple tokens from: #{lbl}" if EXP
            lbl.difference!(CodeSet.new(exp, EPSILON))
            @modified = true
          end
        end
      end
    end

  end # class Filter

end  # module ToknInternal
