module ToknInternal

  class Filter

    attr_reader :modified
    attr_reader :start_state
    attr_accessor :experiment

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
      end

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
        puts "...popped state: #{state.name}" if @experiment
        @state_list << state

        marker_value = marker_value_for(state)
        state_value = node_value(state)
        if !marker_value.nil?
          marker_value = [marker_value, state_value].max
        else
          marker_value = state_value
        end

        puts "    marker: #{marker_value_for(state)} state:#{state_value} max:#{marker_value}" if @experiment

        state.edges.each do |lbl, dest|
          next if dest.finalState
          puts "    edge to: #{dest.name}" if @experiment
          dest_value = node_value(dest)
          puts "     value: #{dest_value}" if @experiment

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

      puts start_state.describe_state_machine if @experiment
      remove_useless_edges
      filter_multiple_tokens_within_edge
      disallow_zero_length_tokens
    end


    private


    def node_value(state)
      value = @node_values[state.id]
      if value.nil?
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
      value
    end

    def marker_value_for(state)
      @node_markers[state.id]
    end

    def store_marker_value(state, marker_value)
      old_marker_value = @node_markers[state.id]
      if old_marker_value.nil? || (old_marker_value < marker_value)
        puts "         (updating marker value for #{state.name} to: #{marker_value})" if @experiment
        @node_markers[state.id] = marker_value
      end
    end

    def disallow_zero_length_tokens
      start_state.edges.each do |lbl, dest|
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

          puts " source marker value #{state.name}:#{source_marker_value} exceeds dest marker value #{dest.name}:#{dest_marker_value}" if @experiment
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
            puts "...removing multiple tokens from: #{lbl}" if @experiment
            lbl.difference!(CodeSet.new(exp, EPSILON))
            @modified = true
          end
        end
      end
    end

  end # class Filter


end  # module ToknInternal
