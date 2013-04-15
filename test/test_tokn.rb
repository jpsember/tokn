require 'test/unit'

require_relative '../lib/tokn/tools.rb'
req('range_partition dfa dfa_builder tokenizer token_defn_parser')


#SINGLETEST = "test_ps_output_multi"
if defined? SINGLETEST
  if main?(__FILE__)
    ARGV.concat("-n  #{SINGLETEST}".split)
  end
end

class TestTokn <  MyTestSuite

  include Tokn, ToknInternal
  
  def suite_setup

    # Make current directory = the one containing this script
    main?(__FILE__)

    if !File.directory?(out_dir)
      Dir.mkdir(out_dir)
    end
    
    @@sampleText = readTextFile("sampletext.txt")
    @@sampleTokens = readTextFile("sampletokens.txt")
  end

  def suite_teardown
    remove_file_or_dir(out_dir)
  end

  def method_setup
  end

  def method_teardown
  end

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
    arr ||= @cs.array
    ia = s.split.map{|n| n.to_i}
    assert_equal(ia,arr)
  end

  def test_100_add
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

  def test_110_intersect
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

  def test_120_difference
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

  def test_130_illegalRange
    prep

    assert_raise(RangeError) { add 60,50 }
    assert_raise(RangeError) { add 60,60 }
  end

  def neg(lower, upper)
    @cs.negate lower, upper
  end

  def test_140_negate
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

  def test_150_remove

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
        s+= ' '
      end
      s += d(x)
    }
    return s
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
      res.concat x.array
    end
    @parResult = res
  end

  def test_160_partition

    newpar
    addset(20,30)
    addset(25,33)
    addset(37)
    addset(40,50)
    @par.prepare

    @par.generatePDF(out_dir)

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

  REGEX_SCRIPT = "(\\-?[0-9]+)|[_a-zA-Z][_a-zA-Z0-9]*|333q"

  TOKEN_SCRIPT2 = <<'END'
        sep:  \s
        tku:  a(a|b)*
        tkv:  b(aa|b*)
        tkw:  bbb
END

  def test_170_build_DFA

    x =  RegParse.new(REGEX_SCRIPT)
    s = x.startState
    x.endState.finalState = true

    s.generatePDF(out_dir,"nfa")

    r = s.reverseNFA()
    r.generatePDF(out_dir,"reversed")

    dfa = DFABuilder.nfa_to_dfa(s)
    dfa.generatePDF(out_dir,"buildDFA")
  end

  def test_180_cvt_NFA_to_DFA

    x = RegParse.new(REGEX_SCRIPT)
    s = x.startState
    x.endState.finalState = true

    s.generatePDF(out_dir,"nfa")

    dfa = DFABuilder.nfa_to_dfa(s)
    dfa.generatePDF(out_dir,"dfa")

    oldToNewMap, maxId2 = dfa.duplicateNFA(42)
    dfa2 = oldToNewMap[dfa]
    dfa2.generatePDF(out_dir,"dfa_duplicated")
  end

  def test_190_TokenDefParser

    s = TOKEN_SCRIPT2

    td = TokenDefParser.new(s)

    tokDFA = td.dfa
    tokDFA.startState.generatePDF(out_dir,"TokenDFA")

  end

  def makeTok
    dfa = DFA.from_script(@@sampleTokens)
    Tokenizer.new(dfa, @@sampleText)
  end

  def test_200_Tokenizer

    tok = makeTok

    tokList = []
    while tok.hasNext
      t = tok.read
      tokList.push(t)
    end

    tok.unread(tokList.size)

    tokList.each do |t1|
      tName = tok.nameOf(t1)
      t2 = tok.read(tName)
    end
  end

  def test_210_Tokenizer_Missing_Expected

    assert_raise TokenizerException do

      tok = makeTok

      tok.read
      tok.read
      tok.read
      tok.read
      tok.read("signedint")
    end

  end

  def test_220_CompileDFAToDisk
    tokScript = @@sampleTokens
    testText = @@sampleText

    destPath = out_path("sampletokens_dfa.txt")

    if File.exist?(destPath)
      File.delete(destPath)
    end
    assert(!File.exist?(destPath))

    dfa = DFA.from_script(tokScript, destPath)
    assert(File.exist?(destPath))

    tok = Tokenizer.new(dfa,  testText)

  end

  def prep2
    testText = @@sampleText
    dfa = DFA.from_file(out_path("sampletokens_dfa.txt"))
    tok = Tokenizer.new(dfa, testText)
  end

  def test_230_readAndUnread
    tok = prep2
    unread = false
    while tok.hasNext
      t = tok.read
#      pr("Read  %-8s %s\n",tok.nameOf(t),d(t))

      if !unread && tok.nameOf(t) == "DO"
#        pr("  ...pushing back four tokens...\n")
        tok.unread(4)
        unread = true
#        pr("  ...and resuming...\n")
      end
    end
  end

  def test_240_UnrecognizedToken
    assert_raise TokenizerException do
      tok = prep2
      while tok.hasNext
        t = tok.read
        if tok.nameOf(t) == "DO"
          tok.read("BRCL") # <== this should raise problem
        end
      end
    end
  end

  def test_250_ReadPastEnd
    assert_raise TokenizerException do
      tok = prep2
      while tok.hasNext
        t = tok.read
      end
      tok.read
    end
  end

  def test_260_UnreadBeforeStart

    assert_raise TokenizerException do
      tok = prep2
      k = 0
      while tok.hasNext
        t = tok.read
        k += 1
        if k == 15
          tok.unread(5)
          tok.unread(7)
          tok.read()
          tok.unread(4)
          tok.unread(3)
        end
      end
      tok.read
    end
  end

  def test_270_filter_ws

    capture_begin
    
    dfa = DFA.from_script_file("sampletokens.txt")
    t = Tokenizer.new(dfa,  readTextFile("sampletext.txt"), "WS")

    while t.hasNext do
      
      tk = t.peek
      
      if t.nameOf(tk) == 'BROP'
        lst = t.readSequenceIf('BROP DO ID BRCL')
        if lst
          puts " ...read BROP DO ID sequence..."  
          lst.each{ |x| puts "   #{d(x)}"}
          next
        else
          puts " ...couldn't find sequence..."  
        end
      end
      
      tk = t.read
      puts d(tk)  
    end
    
    match_expected_output
  end

end

