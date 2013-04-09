tokn 
=======
Tokn is a ruby gem that generates automatons from regular expressions to extract tokens from text files.

Written by Jeff Sember, March 2013.

[Source code documentation can be found here.](http://rubydoc.info/gems/tokn/frames)


Description of the problem
------

For a simple example, suppose a particular text file is designed to have
tokens of the following three types:

		'a' followed by any number of 'a' or 'b'
		'b' followed by either 'aa' or zero or more 'b'
		'bbb'
      
We will also allow an additional token, one or more spaces, to separate them.
These four token types can be written using regular expressions as:
 
		sep:  \s
		tku:  a(a|b)*
		tkv:  b(aa|b*)
		tkw:  bbb
      
We've given each token definition a name (to the left of the colon).  
 
Now suppose your program needs to read a text file and interpret the tokens it
finds there.  

This can be done using the DFA (deterministic finite state automaton) found at: <http://www.cs.ubc.ca/~jpsember/sample_dfa.pdf> 


The token extraction algorithm has these steps:
 
1. Begin at the start state, S0.
1. Look at the next character in the source (text) file.  If there is an arrow (edge) labelled with that character, follow it to another state (it may lead to the same state; that's okay), and advance the cursor to the next character in the source file.
1.  If there's an arrow labelled with a negative number N, don't follow the edge, but instead remember the lowest (i.e., most negative) such N found.
1.  Continue steps 2 and 3 until no further progress is possible.
1.  At this point, N indicates the name of the token found.  The cursor should be restored to the point it was at when that N was recorded.  The token's text consists of the characters from the starting cursor position to that point.
1.  If no N value was recorded, then the source text doesn't match any of the tokens, which is considered an error.
   

The tokn module provides a simple and efficient way to perform this tokenization process.
Its major accomplishment is not just performing the above six steps, but rather that
it also can construct, from a set of token definitions, the DFA to be used in these steps.
Such DFAs are very useful, and can be used by non-Ruby programs as well.


Using the tokn module in a Ruby program
------

There are three object classes of interest: DFA, Tokenizer, and Token.  A DFA is
compiled once from a script containing token definitions (e.g, "tku:  b(aa|b*) ..."),
and can then be stored (either in memory, or on disk as a JSON string) for later use.

When tokens need to be extracted from a source file (or simple string), a Tokenizer is
constructed.  It requires both the DFA and the source file as input.  Once this is done,
individual Token objects can be read from the Tokenizer.

Here's some example Ruby code showing how a text file "source.txt" can be split into 
tokens.  We'll assume there's a text file "tokendefs.txt" that contains the
definitions shown earlier.

		require "Tokenizer"
		include Tokn 
		
		dfa = DFA.from_script(readTextFile("tokendefs.txt"))
		t = Tokenizer.new(dfa, readTextFile("source.txt"))
		
		while t.hasNext
		  k = t.read                     # read token
		  next if t.typeOf(k) == "sep"   # skip 'whitespace'
		  
		  ...do something with the token ...
		
		end
  
If later, another file needs to be tokenized, a new Tokenizer object can be
constructed and given the same dfa object as earlier.


Using the tokn command line utilities
------

The module has two utility scripts: tokncompile, and toknprocess.  These can be
found in the bin/ directory.

The tokncompile script reads a token definition script from standard input, and
compiles it to a DFA.  For example, if you are in the tokn/test/data directory, you can 
type:
  
  tokncompile < sampletokens.txt > compileddfa.txt
  
It will produce the JSON encoding of the appropriate DFA.  For a description of how
this JSON string represents the DFA, see Dfa.rb.

The toknprocess script takes two arguments: the name of a file containing a 
previously compiled DFA, and the name of a source file.  It extracts the sequence
of tokens from the source file to the standard output:

  toknprocess compileddfa.txt sampletext.txt

This will produce the following output:

		WS 1 1 // Example source file that can be tokenized 
		
		WS 2 1 
		
		ID 3 1 speed
		WS 3 6  
		ASSIGN 3 7 =
		WS 3 8  
		INT 3 9 42
		WS 3 11    
		WS 3 14 // speed of object
		
		WS 4 1 
		
		ID 5 1 gravity
		WS 5 8  
		ASSIGN 5 9 =
		WS 5 10  
		DBL 5 11 -9.80
		WS 5 16 
		
		
		ID 7 1 title
		WS 7 6  
		ASSIGN 7 7 =
		WS 7 8  
		LBL 7 9 'This is a string with \' an escaped delimiter'
		WS 7 56 
		
		
		IF 9 1 if
		WS 9 3  
		ID 9 4 gravity
		WS 9 11  
		EQUIV 9 12 ==
		WS 9 14  
		INT 9 15 12
		WS 9 17  
		BROP 9 18 {
		WS 9 19 
		  
		DO 10 3 do
		WS 10 5  
		ID 10 6 something
		WS 10 15 
		
		BRCL 11 1 }
		WS 11 2 
  
The extra linefeeds are the result of a token containing a linefeed.


FAQ
--------

* Why can't I just use Ruby's regular expressions for tokenizing text?

You could construct a regular expression describing each possible token, and use that
to extract a token from the start of a string; you could then remove that token from the
string, and repeat.  The trouble is that the regular expression has no easy way to indicate
which individual token's expression was matched.  You would then (presumably) have to match 
the returned token with each individual regular expression to identify the token type.

Another reason why standard regular expressions can be troublesome is that their 
implementations actually 'recognize' a richer class of tokens than the ones described 
here.  This extra power can come at a cost; in some pathological cases, the running time
can become exponential.

* Is tokn compatible with Unicode?

The tokn tool is capable of extracting tokens made up of characters that have
codes in the entire Unicode range: 0 through 0x10ffff (hex).  In fact, the labels
on the DFA edges can be viewed as sets of any nonnegative integers (negative
values are reserved for the token identifiers).  Note however that the current implementation
only reads Ruby characters from the input, which I believe are only 8 bits wide.

