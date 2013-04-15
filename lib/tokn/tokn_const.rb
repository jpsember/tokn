# Namespace to encompass the portions of the Tokn gem
# accessible to end users
#
module Tokn
end

# Namespace to encompass the portions of the Tokn gem
# used only internally
#
module ToknInternal
  # Token id if text didn't match any tokens in the DFA
  UNKNOWN_TOKEN = -1
  
  # Code for epsilon transitions
  EPSILON = -1

  # One plus the maximum code represented
  CODEMAX = 0x110000

  # Minimum code possible (e.g., indicating a token id)
  CODEMIN = -10000
  
  # Convert a token id (>=0) to an edge label value ( < 0)
  #
  def self.tokenIdToEdgeLabel(tokenId)
    EPSILON-1-tokenId  
  end
  
  # Convert an edge label value ( < 0) to a token id (>=0)
  #
  def self.edgeLabelToTokenId(edgeLabel)
    EPSILON-1-edgeLabel
  end
end

# Convert a .dot file (string) to a PDF file "__mygraph__nnn.pdf" 
# 
# It does this by making a system call to the 'dot' utility.
#
def dotToPDF(dotFile, name = "", test_dir = nil)
  gr = dotFile
  
  raise ArgumentError if !test_dir
  
  dotPath = File.join(test_dir,".__mygraph__.dot")
  writeTextFile(dotPath,gr)
  destName = File.join(test_dir,"__mygraph__"+name+".pdf")
  system("dot -Tpdf "+dotPath+" -o "+destName)
end
