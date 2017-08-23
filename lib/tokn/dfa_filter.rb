module ToknInternal

  class Filter

    attr_reader :modified
    attr_reader :start_state
    attr_accessor :experiment

    INF_DISTANCE = CODEMAX

    def initialize(start_state)
      @start_state = start_state
      @filter_applied = false
    end

    def apply
      raise "filter already applied" if @filter_applied
      @filter_applied = true

      if @experiment
        puts
        puts "============== apply useless edge filter"
        puts
        puts @start_state.describe_state_machine if @experiment
      end

      @modified = false

      build_topological_state_list
      construct_node_values

      @node_distances = {}
      @node_distances[@start_state.id] = node_value(@start_state)

      # Determine minimum distances to each node, as minimum of maximum token values found over all paths ending at node
      #
      @state_list.each do |state_u|
        distance_u = node_distance(state_u)

        puts " processing: #{state_u.name}; distance #{distance_u}" if @experiment

        state_u.edges.each do |lbl, state_v|
          next if state_v.finalState
          value_v = node_value(state_v)
          distance_v = node_distance(state_v)
          distance_v_relaxed = [[distance_u, value_v].max, node_distance(state_v)].min

          puts "  edge to: #{state_v.name}; value #{value_v}; dist #{distance_v}; relaxed #{distance_v_relaxed}" if @experiment

          if distance_v_relaxed < distance_v
            puts "  storing relaxed distance" if @experiment
            @node_distances[state_v.id] = distance_v_relaxed
          end

        end
      end

      if @experiment
        puts "Node distances:"
        @state_list.each do |state|
          puts " #{state.name}: #{@node_distances[state.id]}"
        end
      end

      remove_useless_edges
      filter_multiple_tokens_within_edge
      disallow_zero_length_tokens
    end


    private


    def build_topological_state_list
      @state_list = @start_state.topological_sort
    end

    def construct_node_values
      @node_values = {}
      @state_list.each do |state|
        value = nil
        state.edges.each do |lbl, dest|
          next unless dest.finalState
          puts "....calculating value for state from edge: #{lbl.elements}" if @experiment
          a = lbl.elements
          primeId = a[0]
          value = ToknInternal::edge_label_to_token_id(primeId)
        end
        if value.nil?
          value = -1
        end
        @node_values[state.id] = value
      end
    end

    def node_value(state)
      @node_values[state.id]
    end

    def node_distance(state)
      @node_distances[state.id] || INF_DISTANCE
    end

    def disallow_zero_length_tokens
      start_state.edges.each do |lbl, dest|
        if dest.finalState
          raise "DFA recognizes zero-length tokens!"
        end
      end
    end

    def remove_useless_edges
      @state_list.each do |state_u|

        state_u_distance = node_distance(state_u)

        remove_list = []
        state_u.edges.each_with_index do |edge,edge_index|
          _, state_v = edge
          next if state_v.finalState

          value_v = node_value(state_v)

          if (value_v >= 0 && value_v < state_u_distance)
            puts " source distance #{state_u.name}:#{state_u_distance} exceeds dest token value #{state_v.name}:#{value_v}" if @experiment
            remove_list << edge_index
          end
        end

        next if remove_list.empty?

        @modified = true

        # Remove the useless edges in reverse order, since indices change as we remove them
        remove_list.reverse.each { |x| state_u.remove_edge(x)}

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
            puts "...removing multiple tokens from: #{lbl}" if @experiment
            lbl.difference!(CodeSet.new(exp, EPSILON))
            @modified = true
          end
        end
      end
    end

  end # class Filter


end  # module ToknInternal
