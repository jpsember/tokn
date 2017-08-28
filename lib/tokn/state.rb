module ToknInternal

  # A state within a state machine (NFA or DFA); also, various utility functions
  # for manipulating state machines.  Observe that a state machine can be
  # referred to by its start state.
  #
  # Each state has a set of directed edges to other states, where each edge is
  # labelled with a CodeSet.
  #
  # It also has a unique id (unique within a particular state machine),
  # and a (boolean) final state flag.
  #
  # For debug purposes, both the state and its edges can be labelled.
  #
  class State

    require 'set'

    attr_accessor :id
    attr_accessor :final_state
    attr_accessor :label

    # Edges are a list of [label:CharSetRange, dest:State] pairs
    attr_reader :edges

    def hash
      return @id
    end

    def eql?(other)
      return id == other.id
    end

    def initialize(id)
      @edges = []
      @id = id
    end

    def clearEdges
      @edges.clear
    end

    # Add an edge
    #  codeSet : the character codes to label it with
    #  destState : destination state
    #
    def addEdge(codeSet,destState)
      @edges.push([codeSet, destState])
    end

    def remove_edge(edge_index)
      @edges.delete_at(edge_index) or raise "bad index"
    end

    # Add a e-transition edge
    #  destState : destination state
    #
    def addEps(destState)
      addEdge(CodeSet.new(EPSILON), destState)
    end

    def name
      nm = "S#{id}"
      if label
        nm << ": #{label}"
      end
      nm
    end

    # Normalize a state machine.
    #
    # For each state:
    #  [] merge edges that go to a common state
    #  [] delete edges that have empty labels
    #  [] sort edges by destination state ids
    #
    # > start state
    #
    def self.normalizeStates(start_state)
      start_state.reachable_states.map{|s| s.normalize}
    end

    # Generate a .dot file of the state machine
    #
    # You can convert the resulting .dot file <XXX.dot> to a PostScript file
    # by typing 'dot -O -Tps <XXX.dot>'
    #
    def build_dot_file(title = "nfa")
      stateList = {}

      start_state = self
      genAux( stateList, start_state)

      # Display long labels in an external label box
      #
      box_labels = []
      box_label_map = {}

      g = ''
      g << "digraph #{title} {\n"
      g << " size=\"8,10.5\"\n"
      g << " \"\" [shape=none]\n"

      stateList.each_value do |s|
        g << " \"#{s.name}\" [shape="
        if s.final_state
          g << "doubleoctagon"
        else
          g << "octagon"
        end
        g << "]\n"
      end

      g << "\n \"\" -> \"#{start_state.name}\"\n"
      stateList.each_value do |s|
        s.edges.each do |crs, s2|
          crs_text = crs.to_s
          displayed_text = crs_text

          # Put label into external label box if it's long
          #
          use_external_label = crs_text.length > 4
          if use_external_label
            index = box_label_map[crs_text]
            if index.nil?
              index = 1 + box_labels.size
              box_labels << crs_text
              box_label_map[crs_text] = index
            end
            displayed_text = "\##{index}"
          end

          g << " \"#{s.name}\" -> \"#{s2.name}\" [label=\"#{displayed_text}\"][fontsize=12]"
          if !use_external_label
            g << "[fontname=Courier]"
          end
          g << "\n"
        end
      end

      # Plot the label box if it's not empty
      #
      if !box_labels.empty?
        text = "LABELS\n\n"
        box_labels.each_with_index do |label,index|
          text << "#" << (1+index).to_s << ": " << label << "\\l"
        end
        g << "\"Legend\" [shape=note,label=\"#{text}\",fontname=Courier,fontsize=12]\n"
      end

      g << "\n}\n"
      g
    end


    def generate_pdf(path)
      # Put the pdf within OSX's Desktop
      path = "#{Dir.home}/Desktop/#{File.basename(path)}"

      puts "======= Generating: #{path}"

      require "tempfile"

      dot_file = Tempfile.new('dotfile')
      File.write(dot_file.path, self.build_dot_file("dfa"))
      system("dot -o#{path} -Tpdf #{dot_file.path}")
      dot_file.unlink
    end


    # Normalize a state
    #
    #  [] merge edges that go to a common state
    #  [] delete edges that have empty labels
    #  [] sort edges by destination state ids
    #
    def normalize

      @edges.sort!{|x,y|
        _,dest1 = x
        _,dest2 = y
        dest1.id <=> dest2.id
      }

      new_edges = []
      prev_label, prev_dest = nil,nil

      edges.each do |label,dest|
        if prev_dest and prev_dest.id == dest.id
          prev_label.addSet(label)
        else
          if prev_dest
            new_edges.push([prev_label,prev_dest])
          end
          # Must start a fresh copy!  Don't want to modify the original label.
          prev_label = label.makeCopy()
          prev_dest = dest
        end
      end

      if prev_dest
        new_edges.push([prev_label,prev_dest])
      end

      @edges = new_edges
    end

    # Duplicate the NFA reachable from this state, possibly with new ids
    #
    # > dupBaseId : lowest id to use for duplicate
    # < [ map of original states => duplicate states;
    #     1 + highest id in new NFA ]
    #
    def duplicateNFA(dupBaseId)
      oldStates = reachable_states
      oldMinId, oldMaxId = range_of_state_ids(oldStates)

      oldToNewStateMap = {}

      oldStates.each do |s|
        s2 = State.new((s.id - oldMinId) + dupBaseId)
        s2.final_state = s.final_state
        s2.label = s.label

        oldToNewStateMap[s] = s2
      end

      oldStates.each do |s|
        s2 = oldToNewStateMap[s]
        s.edges.each{ |lbl,dest|  s2.addEdge(lbl, oldToNewStateMap[dest])}
      end

      [oldToNewStateMap, (oldMaxId - oldMinId) + dupBaseId]
    end

    # Construct the reverse of the NFA starting at this state
    # < start state of reversed NFA
    #
    def reverseNFA

      edgeList = []

      newStartStateList = []
      newFinalStateList = []

      newStateMap = {}

      stateSet = reachable_states
      stateSet.each do |s|
        u = State.new(s.id)
        newStateMap[u.id] = u

        if s.id == self.id
          newFinalStateList.push(u)
          u.final_state = true
        end

        if s.final_state
          newStartStateList.push(u)
        end

        s.edges.each {|lbl, dest| edgeList.push([dest.id, s.id, lbl])}

      end

      edgeList.each do |srcId, destId, lbl|
        srcState = newStateMap[srcId]
        destState = newStateMap[destId]
        srcState.addEdge(lbl, destState)
      end

      # Create a distinguished start node that points to each of the start nodes
      _,maxId = range_of_state_ids(stateSet)
      w = State.new(maxId)
      newStartStateList.each {|s| w.addEps(s)}
      w
    end

    # Build set of states reachable from this state
    #
    def reachable_states
      set = Set.new
      stack = []
      stack.push(self)

      while !stack.empty?
        st = stack.pop
        set.add(st)
        st.edges.each do |lbl, dest|
          if set.add?(dest)
            stack.push(dest)
          end
        end
      end
      set
    end

    # Get range of states in a set
    #
    # returns [lowest id in set, 1 + highest id in set]
    #
    def range_of_state_ids(states)
      max_id = -1
      min_id = -1

      states.each do |state|
        if max_id < 0
          max_id = state.id
          min_id = state.id
        else
          if min_id > state.id
            min_id = state.id
          end
          if max_id < state.id
            max_id = state.id
          end
        end
      end
      [min_id, max_id + 1]
    end

    def to_s
      s = ""
      if self.final_state
        s << "*"
      else
        s << " "
      end
      s << self.name
      self.edges.each do |crs, s2|
        s << " -> (#{s2.name} | #{crs.to_s})"
      end
      s
    end

    def inspect
      to_s
    end

    # Construct string representation of the state machine reachable from this state
    #
    def describe_state_machine
      str = ""
      self.reachable_states.sort{|x,y| x.id <=> y.id}.each do |x|
        str << x.to_s << "\n"
      end
      str
    end


    private


    def genAux(stateList, st)
      if not stateList.member?(st.name)
        stateList[st.name] = st
        st.edges.each {|label, dest| genAux(stateList, dest)}
      end
    end

  end

end  # module
