module ToknInternal

class TopSort

  PERMANENT = 1
  TEMPORARY = 2

  def initialize(start_state)
    @start_state = start_state
  end

  def perform
    @sorted_states = []
    @marks = {}
    visit(@start_state)
    @sorted_states.reverse!
  end

  def sorted_states
    @sorted_states
  end

  def visit(state)
    m = @marks[state.id]
    return if m == PERMANENT
    return if m == TEMPORARY

    @marks[state.id] = TEMPORARY
    state.edges.each do |crs, dest_state|
      visit(dest_state)
    end
    @marks[state.id] = PERMANENT
    @sorted_states << state

  end

end # class TopSort

end # module
