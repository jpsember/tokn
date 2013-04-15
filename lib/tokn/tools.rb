require 'set'
require 'fileutils'

# Various utility and debug convenience functions.
#

# Perform 'require_relative' on a set of files
#
# fileListStr : space-delimited file/path items, without .rb extensions
# subdir : optional path to files relative to tools.rb
#
def req(fileListStr,subdir = nil)
  fileListStr.split(' ').each do |x|
    if subdir
      x = File.join(subdir,x)
    end
    x += '.rb'
    require_relative(x)
  end
end

# Shorthand for printf(...)
#
def pr(*args)
  printf(*args)
end


# Convert an object to a human-readable string;
# should be considered a debug-only feature
#
def d(arg)
  arg.nil? ? "<nil>" : arg.inspect
end

# Assert that a value is true.  Should be considered a 
# very temporary, debug-only option; it is slow and
# generates a warning that it is being called.
#
def myAssert(cond, *msg)
  oneTimeAlert("warning",0,"Checking assertion")
  if not cond
    str = (msg.size == 0) ? "assertion error" : sprintf(*msg)
    raise Exception, str
  end
end



# Convert a .dot file (string) to a PDF file "__mygraph__nnn.pdf" 
# in the test directory.
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

# Extensions to the Enumerable module
#
module Enumerable
  # Calculate a value for each item, and return the item with the
  # highest value, its index, and the value.
  # @yieldparam function to calculate value of an object, given that object as a parameter
  # @return the triple [object, index, value] reflecting the maximum value, or
  #   nil if there were no items
  def max_with_index 
    
    best = nil
    
    each_with_index do |obj,ind|
      sc = yield(obj)
      if !best || best[2] < sc
        best = [obj,ind,sc]
      end
    end
    best
  end
end


# Get a nice, concise description of the file and line
# of some caller within the stack.
# 
#  nSkip : the number of items deep in the call stack to look
#
def getCallerLocation(nSkip = 2) 
  
  filename = nil
  linenumber = nil
  
  if nSkip >= 0 && nSkip < caller.size
    fi = caller[nSkip]   
    
    i = fi.index(':')
    j = nil
    if i
      j = fi.index(':',i+1)
    end
    if j
      pth = fi[0,i].split('/')
      if pth.size
        filename = pth[-1]
      end
      linenumber = fi[i+1,j-i-1].to_i
    end
  end
  if filename && linenumber
    loc = filename + " ("+linenumber.to_s+")"
  else 
    loc = "(UNKNOWN LOCATION)"
  end
  loc
end

# Set of alert strings that have already been reported
# (to avoid printing anything on subsequent invocations)
#
$AlertStrings = Set.new

# Print a message if it hasn't yet been printed,
# which includes the caller's location
#
# > typeString : e.g., "warning", "unimplemented"
# > nSkip : the number of levels deep that the caller is in the stack
# > args : if present, calls sprintf(...) with these to append to the message
#
def oneTimeAlert(typeString, nSkip, *args) 
  loc = getCallerLocation(nSkip + 2)
  s = "*** "+typeString+" " + loc
  if args && args.size
    s2 = sprintf(args[0], *args[1..-1])
    msg = s + ": " + s2
  else 
    msg = s
  end

  if $AlertStrings.add?(msg)
    puts msg
  end
end
     
# Print a 'warning' alert, one time only 
#   
def warn(*args) 
  oneTimeAlert("warning",0, *args)
end

# Print an 'unimplemented' alert, one time only 
#   
def unimp(*args)
  oneTimeAlert("unimplemented", 0, *args)
end

# Write a string to a text file
#
def writeTextFile(path, contents)
    File.open(path, "wb") {|f| f.write(contents) }
end

# Read a file's contents, return as a string
#
def readTextFile(path)
  contents = nil
  File.open(path,"rb") {|f| contents = f.read }
  contents
end

# Delete a file or directory, if it exists.
# Caution!  If directory, deletes all files and subdirectories.
def remove_file_or_dir(pth)
  if File.directory?(pth)
    FileUtils.remove_dir(pth)
  elsif File.file?(pth)
    FileUtils.remove_file(pth)
  end
end  

# Method that takes a code block as an argument to 
# achieve the same functionality as Java/C++'s
#  do {
#    ...
#    ...  possibly with 'break' to jump to the end ...
#  } while (false);
#
def block
  yield
end

# Exception class for objects in illegal states
#
class IllegalStateException < Exception
end
  

# Convenience method to detect if a script is being run
# e.g. as a 'main' method (for debug purposes only).
# If so, it changes the current directory to the 
# directory containing the script (if such a directory exists).
#
# @param file pass __FILE__ in here
# @return true if so
# 
def main?(file)
  
  scr = $0

  # The test/unit framework seems to be adding a suffix ": xxx#xxx.."
  # to the .rb filename, so adjust in this case
  i = scr.index(".rb: ")
  if i
    scr = scr[0...i+3]
  end

  if (ret = (file == scr))
    dr = File.dirname(file)
    if File.directory?(dr)
      Dir.chdir(dr)
    end
  end
  ret
end

if defined? Test::Unit
  
  # A simple extension to Ruby's Test::Unit class that provides
  # suite-level setup/teardown methods.
  # 
  # If test suite functionality is desired within a script,
  # then require 'test/unit' before requiring 'tools.rb'.
  # This will cause the following class, MyTestSuite, to be defined.
  #
  # The user's test script can define subclasses of this,
  # and declare test methods with the name 'test_xxxx', where
  # xxxx is lexicographically between 01 and zz.
  #
  # There are two levels of setup/teardown called : suite level, and
  # method level.  For example, if the user's test class performs two tests:
  #
  #  def test_b   ... end
  #  def test_c   ... end
  #
  # Then the test framework will make these calls:
  #
  #     suite_setup
  #   
  #     method_setup
  #     test_b
  #     method_teardown
  #   
  #     method_setup
  #     test_c
  #     method_teardown
  #   
  #     suite_teardown
  #
  # Notes
  # -----
  # 1) The usual setup / teardown methods should NOT be overridden; instead,
  # use the method_xxx alternatives.
  #
  # 2) The base class implementations of method_/suite_xxx do nothing.
  # 
  # 3) The number of test cases reported may be higher than you expect, since
  # there are additional test methods defined by the TestSuite class to
  # implement the suite setup / teardown functionality.
  #
  # 4) Avoid naming test methods that fall outside of test_01 ... test_zz.
  #
  class MyTestSuite < Test::Unit::TestCase
    
    # This is named to be the FIRST test called.  It
    # will do suite-level setup, and nothing else.
    def test_00_setup
      @@suiteSetup = true
      suite_setup()
    end
    
    # This is named to be the LAST test called.  It
    # will do suite-level teardown, and nothing else.
    def test_zzzzzz_teardown
      suite_teardown()
      @@suiteSetup = false
    end
    
    # True if called within suite-level setup/teardown window
    def _suite_active?
      !(@__name__ == "test_00_setup" || @__name__ == "test_zzzzzz_teardown")
    end
    
    def setup
      if _suite_active?
        # If only a specific test was requested, the
        # suite setup may not have run... if not, do it now.
        if !defined? @@suiteSetup
          suite_setup
        end
        return 
      end
      method_setup
    end
    
    def out_dir
      "_output_"
    end
    
    def out_path(f)
      File.join(out_dir,f)
    end
    
    def teardown
      if _suite_active?
        if !defined? @@suiteSetup
          suite_teardown
        end
        return 
      end
      method_teardown
    end
  
    def suite_setup
    end
    
    def suite_teardown
    end
    
    def method_setup
    end
    
    def method_teardown
    end
  end
end

