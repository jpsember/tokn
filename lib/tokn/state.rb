require 'set'
require_relative 'tools'

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
    
    # Produce a readable description of an NFA, for debug purposes
    #
    # > st  start state
    #
    def self.dumpNFA(st)
      str = "NFA:\n"
      map,_,_ = st.reachableStates
      map.each do |s| 
        str += " "+d(s)+"\n"
        str += "  edges= "+d(s.edges)+"\n"
        s.edges.each{ |lbl,dest| str += "   "+d(lbl)+"  ==> "+d(dest)+"\n"}
      end
      str
    end
  
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
    
    def inspect   
      name
    end 
   
    def name
      nm = 'S' + d(id)
      if label
        nm += ": "+label
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
    
    
    # Generate a PDF of the state machine;
    # Makes a system call to the dot utility to convert a .dot file to a .pdf
    #
    def generatePDF(dir = nil, title = "nfa")
      stateList = {}
      
      startState = self
      genAux( stateList, startState)
      
      g = ""
      g += "digraph "+title+" {\n"
      g += " '' [shape=none]\n"
      
      stateList.each_value do |s| 
        g += " '" + s.name + "' [shape="
        if s.finalState?
          g += "doubleoctagon"
        else
          g += "octagon"
        end
        g += "]\n"
      end
    
      g += "\n"
      g += " '' -> '" + startState.name + "'\n"
      stateList.each_value do |s| 
        s.edges.each do |crs, s2|
          g += " '"+s.name+"' -> '" + s2.name + "' [label='"
          g += d(crs)
          g += "'][fontname=Courier][fontsize=12]\n"
        end
      end
    
      g += "\n}\n"
      g.gsub!( /'/, '"' )
      
      dotToPDF(g,title,dir)
    end
  
    
    # Normalize a state 
    # 
    #  [] merge edges that go to a common state
    #  [] delete edges that have empty labels
    #  [] sort edges by destination state ids
    #
    def normalize()
      
      db = false
      
      !db || pr("\n\nnormalize state:\n  %s\nedges=\n%s\n",d(self),d(@edges))
      
      @edges.sort!{|x,y| 
        label1,dest1 = x
        label2,dest2 = y
        dest1.id <=> dest2.id
      }
      !db || pr(" sorted edges: %s\n",d(@edges))
      
      newEdges = []
      prevLabel, prevDest = nil,nil
      
      edges.each do |label,dest|
        !db || pr("  processing edge  %s,  %s\n",d(label),d(dest))
      
        if prevDest and prevDest.id == dest.id
          # changed = true
          !db || pr("    adding set %s to prevLabel %s...\n",d(label),d(prevLabel))
          prevLabel.addSet(label)
          !db || pr("    ...now %s\n",d(prevLabel))
        else
          if prevDest
            newEdges.push([prevLabel,prevDest])
          end
          # Must start a fresh copy!  Don't want to modify the original label.
          prevLabel = label.makeCopy()
          prevDest = dest
          !db || pr("    pushed onto new edges\n")  
          end
        end
        if prevDest
           newEdges.push([prevLabel,prevDest])
        end
              
      @edges = newEdges
      !db || pr("edges now: %s\n",d(@edges))
    end
  
  
    # Duplicate the NFA reachable from this state, possibly with new ids
    #
    # > dupBaseId : lowest id to use for duplicate; if nil, uses 
    #     next available id
    # < [ map of original states => duplicate states;
    #     1 + highest id in new NFA ]
    #    
    def duplicateNFA(dupBaseId = nil)
      oldStates, oldMinId, oldMaxId = reachableStates()
      dupBaseId ||= oldMaxId
      
       
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
    def reverseNFA()
      
      stateSet, minId, maxId = reachableStates()
      
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
      
      maxId = nil
      minId = nil
      
      while !stack.empty?
        st = stack.pop
        set.add(st)
        
        if !minId || minId > st.id
          minId = st.id
        end
        if !maxId || maxId <= st.id
          maxId = 1 + st.id
        end
        
        st.edges.each do |lbl, dest|
          if set.add?(dest)
            stack.push(dest)
          end
        end
      end
      [set, minId,  maxId]
    end
    
  
    private
    
    def genAux(stateList, st)
      if not stateList.member?(st.name)
        stateList[st.name] = st
        st.edges.each {|label, dest| genAux(stateList, dest)}
      end
    end
   
  end

end  # module ToknInternal

