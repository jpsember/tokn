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

  attr_accessor :id
  attr_accessor :finalState
  alias_method :finalState?, :finalState
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
  def self.normalizeStates(startState)
    stateSet, _,_ = startState.reachableStates
    stateSet.map{|s| s.normalize}
  end

  # Generate a .dot file of the state machine
  #
  # You can convert the resulting .dot file <XXX.dot> to a PostScript file
  # by typing 'dot -O -Tps <XXX.dot>'
  #
  def build_dot_file(title = "nfa")
    stateList = {}

    startState = self
    genAux( stateList, startState)

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
      if s.finalState?
        g << "doubleoctagon"
      else
        g << "octagon"
      end
      g << "]\n"
    end

    g << "\n \"\" -> \"#{startState.name}\"\n"
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

  # Normalize a state
  #
  #  [] merge edges that go to a common state
  #  [] delete edges that have empty labels
  #  [] sort edges by destination state ids
  #
  def normalize()

    @edges.sort!{|x,y|
      _,dest1 = x
      _,dest2 = y
      dest1.id <=> dest2.id
    }

    newEdges = []
    prevLabel, prevDest = nil,nil

    edges.each do |label,dest|
      if prevDest and prevDest.id == dest.id
        # changed = true
        prevLabel.addSet(label)
      else
        if prevDest
          newEdges.push([prevLabel,prevDest])
        end
        # Must start a fresh copy!  Don't want to modify the original label.
        prevLabel = label.makeCopy()
        prevDest = dest
      end
    end

    if prevDest
      newEdges.push([prevLabel,prevDest])
    end

    @edges = newEdges
  end

  # Duplicate the NFA reachable from this state, possibly with new ids
  #
  # > dupBaseId : lowest id to use for duplicate
  # < [ map of original states => duplicate states;
  #     1 + highest id in new NFA ]
  #
  def duplicateNFA(dupBaseId)
    oldStates, oldMinId, oldMaxId = reachableStates()

    oldToNewStateMap = {}

    oldStates.each do |s|
      s2 = State.new((s.id - oldMinId) + dupBaseId)
      s2.finalState = s.finalState?
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

    stateSet, _, maxId = reachableStates()

    edgeList = []

    newStartStateList = []
    newFinalStateList = []

    newStateMap = {}

    stateSet.each do |s|
      u = State.new(s.id)
      newStateMap[u.id] = u

      if s.id == self.id
        newFinalStateList.push(u)
        u.finalState = true
      end

      if s.finalState?
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
    w = State.new(maxId)
    newStartStateList.each {|s| w.addEps(s)}
    w
  end

  # Build set of states reachable from this state
  #
  # > list of starting states
  # < [ set,   set of states reachable from those states
  #     minId, lowest id in set
  #     maxId    1 + highest id in set
  #   ]
  #
  def reachableStates()
    set = Set.new
    stack = []
    stack.push(self)

    maxId = self.id
    minId = self.id

    while !stack.empty?
      st = stack.pop
      set.add(st)
      if minId > st.id
        minId = st.id
      end
      if maxId < st.id
        maxId = st.id
      end

      st.edges.each do |lbl, dest|
        if set.add?(dest)
          stack.push(dest)
        end
      end
    end
    [set, minId,  1+maxId]
  end

  def to_s
    s = self.name
    s << '(F)' if self.finalState
    self.edges.each do |crs, s2|
        s << "    ->(#{s2.name}|#{crs.to_s})"
    end
    s
  end

  def inspect
    to_s
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
