require 'js_base/js_test'
require 'tokn'

class TestCodeSet < JSTest

  include ToknInternal

  def add(lower, upper = nil)
    @cs.add(lower,upper)
  end

  def remove(lower, upper = nil)
    @cs.remove(lower,upper)
  end

  def swap
    @ct = @cs
    prep
  end

  def isect
    @cs.intersect!(@ct)
  end

  def diff
    @cs.difference!(@ct)
  end

  def equ(s, arr = nil)
    arr ||= @cs.elements
    ia = s.split.map{|n| n.to_i}
    assert_equal(ia,arr)
  end

  def test_add
    prep

    add(72,81)
    equ '72 81'

    add(50)
    equ '50 51 72 81'

    add(75,77)
    equ '50 51 72 81'

    add(72,78)
    equ '50 51 72 81'

    add(70,78)
    equ '50 51 70 81'

    add 60
    equ '50 51 60 61 70 81'

    add 40
    equ '40 41 50 51 60 61 70 81'

    add 41
    equ '40 42 50 51 60 61 70 81'

    add 81
    equ '40 42 50 51 60 61 70 82'

    add 83
    equ '40 42 50 51 60 61 70 82 83 84'

    add 49,84
    equ '40 42 49 84'

    add 39,86
    equ '39 86'
  end

  def test_intersect
    prep
    add 39,86
    swap
    add 50,70
    isect
    equ '50 70'

    swap
    add 20,25
    add 35,51
    add 62,68
    add 72,80
    isect
    equ '50 51 62 68'

    prep
    swap
    add 50,70
    isect
    equ ''

    add 50,70
    swap
    add 50,70
    isect
    equ '50 70'

    prep
    add 20,25
    swap
    add 25,30
    isect
    equ ''
  end

  def test_difference
    prep
    add 20,30
    add 40,50
    swap

    add 20,80
    diff
    equ '30 40 50 80'

    prep
    add 19,32
    diff
    equ '19 20 30 32'

    prep
    add 30,40
    diff
    equ '30 40'

    prep
    add 20,30
    add 40,50
    diff
    equ ''

    prep
    add 19,30
    add 40,50
    diff
    equ '19 20'

    prep
    add 20,30
    add 40,51
    diff
    equ '50 51'

  end

  def prep
    @cs =  CodeSet.new
  end

  def test_illegalRange
    prep

    assert_raises(RangeError) { add 60,50 }
    assert_raises(RangeError) { add 60,60 }
  end

  def neg(lower, upper)
    @cs.negate lower, upper
  end

  def test_negate
    prep
    add 10,15
    add 20,25
    add 30
    add 40,45
    equ '10 15 20 25 30 31 40 45'
    neg 22,37
    equ '10 15 20 22 25 30 31 37 40 45'
    neg 25,27
    equ '10 15 20 22 27 30 31 37 40 45'
    neg 15,20
    equ '10 22 27 30 31 37 40 45'

    prep
    add 10,22
    @cs.negate
    equ '0 10 22 1114112'

    prep
    add 10,20
    neg 10,20
    equ ''

    prep
    add 10,20
    add 30,40
    neg 5,10
    equ '5 20 30 40'

    prep
    add 10,20
    add 30,40
    neg 25,30
    equ '10 20 25 40'

    prep
    add 10,20
    add 30,40
    neg 40,50
    equ '10 20 30 50'

    prep
    add 10,20
    add 30,40
    neg 41,50
    equ '10 20 30 40 41 50'

    prep
    add 10,20
    add 30,40
    neg 15,35
    equ '10 15 20 30 35 40'
  end

  def test_remove

    prep
    add 10,20
    add 30,40
    remove 29,41
    equ '10 20'

    add 30,40
    equ '10 20 30 40'

    remove 20,30
    equ '10 20 30 40'

    remove 15,35
    equ '10 15 35 40'

    remove 10,15
    equ '35 40'
    remove 35
    equ '36 40'
    remove 40
    equ '36 40'
    remove 38
    equ '36 38 39 40'
    remove 37,39
    equ '36 37 39 40'

  end

  def dset(st)
    s = ''
    st.each{|x|
      if s.length > 0
        s << ' '
      end
      s << x
    }
    s
  end

  def newpar
    @par =  RangePartition.new
  end

  def addset(lower, upper = nil)
    upper ||= lower + 1
    r =  CodeSet.new(lower,upper)
    @par.addSet(r)
  end

  def apply
    list = @par.apply(@cs)
    res = []
    list.each do |x|
      res.concat(x.elements)
    end
    @parResult = res
  end

  def test_partition
    newpar
    addset(20,30)
    addset(25,33)
    addset(37)
    addset(40,50)
    @par.prepare

    prep
    add 25,33

    apply
    equ('25 30 30 33', @parResult)

    prep
    add 37
    apply
    equ('37 38', @parResult)

    prep
    add 40,50
    apply
    equ('40 50', @parResult)
  end

  def test_single_value_1
    prep
    add(5)
    assert !(@cs.single_value.nil?)
  end

  def test_single_value_2
    prep
    add(5)
    @cs.negate
    assert (@cs.single_value.nil?)
  end

  def test_single_value_3
    prep
    add(5)
    add(6)
    assert (@cs.single_value.nil?)
  end

  def test_single_value_4
    prep
    add(5)
    add(8)
    assert (@cs.single_value.nil?)
  end


end
