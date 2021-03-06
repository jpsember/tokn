require "json"

module Tokn

  # A DFA for tokenizing; includes pointer to a start state, and
  # a list of token names
  #
  class DFA

    def self.version
      4.0
    end

    include ToknInternal

    # Serialize DFA to a JSON string.
    # The DFA in JSON form has this structure:
    #
    #  {
    #    "version" => version number (float)
    #    "tokens" => array of token names (strings)
    #    "states" => array of states, ordered by id (0,1,..)
    #    "final" => id of final state
    #  }
    #
    # Each state is a list of edge info:
    #  [code_set1, dest_id1, code_set2, destination_id2, ...]
    #
    # The last destination_id is optional.  If missing, it is the final state.
    #
    # The code set is the json representation of a CodeSet.
    #
    def to_json

      dict = {}
      dict["version"] = DFA.version
      dict["tokens"] = @token_names
      state_info = []

      state_list = get_ordered_state_list
      final_states = state_list.select{|state| state.final_state}
      raise "bad final states" unless final_states.size == 1
      final_state_id = final_states[0].id
      dict["final"] = final_state_id
      dict["states"] = state_info

      state_list.each do |state|
        edge_list = []

        # If there's an edge to a final state, put it last;
        # there should be at most one

        edge_to_final_state = nil
        state.edges.each do |edge|
          lbl, dest = edge
          if dest.id == final_state_id
            raise "multiple edges to final state" if edge_to_final_state
            edge_to_final_state = edge
            next
          end
          edge_list << lbl.to_json
          edge_list << dest.id
        end

        # If there was an edge to a final state, add it; but exclude the final state
        if edge_to_final_state
          lbl, _ = edge_to_final_state
          edge_list << lbl.to_json
        end

        state_info << edge_list
      end

      JSON.generate(dict)
    end


    # Compile a Tokenizer DFA from a JSON string
    #
    def self.from_json(json_str)
      h = JSON.parse(json_str)
      version = h["version"]

      if !version || version.floor != DFA.version.floor
        raise ArgumentError,"Bad or missing version number: #{version}, expected #{DFA.version}"
      end

      token_names = h["tokens"]
      json_states = h["states"]
      final_state_id = h["final"] or raise "missing final state"

      states_array = []
      json_states.size.times do |i|
        states_array.push(State.new(i))
      end

      states_array.each do |s|
        state_edge_list = json_states[s.id]
        max_cursor = state_edge_list.size
        s.final_state = (s.id == final_state_id)
        cursor = 0
        while cursor < max_cursor
          label = state_edge_list[cursor]
          cursor += 1
          destination_state = final_state_id
          if cursor < max_cursor
            destination_state = state_edge_list[cursor]
            cursor += 1
          end
          s.addEdge(CodeSet.from_json(label), states_array[destination_state])
        end
      end

      DFA.new(token_names, states_array[0])
    end

    attr_reader :start_state, :token_names

    # Construct a DFA, given a list of token names and a starting state.
    #
    def initialize(token_name_list, start_state)

      if (start_state.id != 0)
        raise ArgumentError, "Start state id must be zero"
      end

      @token_names = token_name_list
      @start_state = start_state
      @token_id_map = nil
    end

    # Determine the name of a token, given its id.
    # Returns <UNKNOWN> if its id is UNKNOWN_TOKEN, or <EOF> if
    # the token_id is nil.  Otherwise, assumes token_id is 0 ... n-1, where
    # n is the number of token names in the DFA.
    #
    def token_name(token_id)
      if token_id.nil?
        "<EOF>"
      elsif token_id == UNKNOWN_TOKEN
        "<UNKNOWN>"
      else
        if token_id < 0 || token_id >= @token_names.size
          raise IndexError, "No such token id:#{token_id}"
        end
        @token_names[token_id]
      end
    end

    # Get id of token given its name, or nil if no such token found
    #
    def token_id(token_name)
      if @token_id_map.nil?
        @token_id_map = {}
        @token_names.each_with_index do |name, i|
          @token_id_map[name] = i
        end
      end
      @token_id_map[token_name]
    end


    private


    def get_ordered_state_list
      raise ArgumentError, "Bad start state" if @start_state.id != 0
      state_list = []
      id_to_state_map = {}
      @start_state.reachable_states.each{|st| id_to_state_map[st.id] = st}
      id_to_state_map.size.times do |id|
        state = id_to_state_map[id] or raise ArgumentError, "unexpected state ids"
        state_list << state
      end
      state_list
    end

  end


end  # module Tokn
