module ToknInternal

  class Filter

    attr_reader :modified
    attr_reader :start_state
    attr_accessor :verbose

    INF_DISTANCE = CODEMAX

    def initialize(start_state)
      @start_state = start_state
      @filter_applied = false
      @verbose = false
    end

    def apply
      raise "filter already applied" if @filter_applied
      @filter_applied = true

      if @verbose
        puts
        puts "============== apply useless edge filter"
        puts
        puts @start_state.describe_state_machine
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

        puts " processing: #{state_u.name}; distance #{distance_u}" if @verbose

        state_u.edges.each do |lbl, state_v|
          next if state_v.final_state
          value_v = node_value(state_v)
          distance_v = node_distance(state_v)
          distance_v_relaxed = [[distance_u, value_v].max, node_distance(state_v)].min

          puts "  edge to: #{state_v.name}; value #{value_v}; dist #{distance_v}; relaxed #{distance_v_relaxed}" if @verbose

          if distance_v_relaxed < distance_v
            puts "  storing relaxed distance" if @verbose
            @node_distances[state_v.id] = distance_v_relaxed
          end

        end
      end

      if @verbose
        puts "Node distances:"
        @state_list.each do |state|
          puts " #{state.name}: #{@node_distances[state.id]}"
        end
      end

    end


    private


    def build_topological_state_list
      sorter = TopSort.new(@start_state)
      sorter.perform
      @state_list = sorter.sorted_states
    end

    def construct_node_values
      @node_values = {}
      @state_list.each do |state|
        value = nil
        state.edges.each do |lbl, dest|
          next unless dest.final_state
          puts "....calculating value for state from edge: #{lbl.elements}" if @verbose
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

  end # class Filter

end  # module ToknInternal
