require 'set'
require 'fileutils'

# Various utility and debug convenience functions.
#

# A string containing a single zero, with ASCII 8-bit encoding (i.e., plain old bytes)
ZERO_CHAR = "\0".force_encoding("ASCII-8BIT")

def zero_bytes(count)
  ZERO_CHAR * count
end

# Convenience method to perform 'require_relative' on a set of files
#
# @param fileListStr  space-delimited file/path items, without .rb extensions
# @param subdir  optional path to files relative to this file
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
# @param args passed to printf
def pr(*args)
  printf(*args)
end

# Convert an object to a human-readable string,
# or <nil>; should be considered a debug-only feature
# 
def d(arg)
  arg.nil? ? "<nil>" : arg.inspect
end

# Convert an object to a human-readable string,
# by calling a type-appropriate function: da, dh, or just d.
# @param arg object
# @param indent optional indentation for pretty printing; if result
#          spans multiple lines, each line should be indented by this amount
#
def d2(arg, indent = 0)
  return da(arg, indent) if arg.is_a? Array
  return dh(arg, indent) if arg.is_a? Hash
  return df(arg) if arg.class == FalseClass || arg.class == TrueClass
  return d(arg)  
end

# Convert an object to a human-readable string, prefixed with its type
#
def dt(arg)
  if arg.nil?
    return "<nil>"
  end
  s = arg.class.to_s
  s << ':'
  s << arg.inspect
  s
end

# Append a particular number of spaces to a string
def add_sp(s, indent = 0)
  s << ' ' * indent
end

# Pretty-print an array,
# one element to a line
# @param indent indentation of each line, in spaces
def da(array, indent = 0)
  return d(array) if !array
  s = 'Array ['
  indent += 2
  array.each do |x| 
    s << "\n"
    add_sp(s,indent)
    s2 = d2(x, indent + 2)
    s << s2
  end
  s << " ]"
  s
end

# Pretty-print a hash,
# one element to a line
# @param indent indentation of each line, in spaces
def dh(hash, indent = 0)
  return d(hash) if !hash
  s = 'Hash {'
  indent += 2
  hash.each_pair do |key,val| 
    s2 = d(key)
    s3 = d2(val, indent + 4)
    s << "\n " 
    add_sp(s,indent)
    s << s2.chomp << " => " << s3.chomp
  end
  s << " }"
  s
end

# Generate debug description of a boolean value
# @param flag value to interpret as a boolean; prints 'T' iff not nil
# @param label optional label 
def df(flag, label=nil)
  s = ''
  if label
    s << label << ':'
  end
  s << (flag ? "T" : "F")
  s << ' '
  s
end

# Assert that a value is true.  Should be considered a 
# very temporary, debug-only option; it is slow and
# generates a warning that it is being called.
# @param cond condition
# @param msg generates additional message using printf(), if these arguments exist
def assert!(cond, *msg)
  one_time_alert("warning",0,"Checking assertion")
  if not cond
    str = (msg.size == 0) ? "assertion error" : sprintf(*msg)
    raise Exception, str
  end
end

# Abort with message about unimplemented code
#
def unimp!(msg = nil)
  msg2 = "Unimplemented code"
  if msg
    msg2 << ": " << msg
  end
  raise Exception, msg2
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
# @param nSkip the number of items deep in the call stack to look
#
def get_caller_location(nSkip = 2) 
  
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
      linenumber = fi[i+1,j-i-1]  
    end
  end
  if filename && linenumber
    loc = filename + " ("+linenumber+")"
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
# @param typeString  e.g., "warning", "unimplemented"
# @param nSkip    the number of levels deep that the caller is in the stack
# @param args    if present, calls sprintf(...) with these to append to the message
#
def one_time_alert(typeString, nSkip, *args) 
  loc = get_caller_location(nSkip + 2)
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
# @param args if present, calls printf() with these
def warn(*args) 
  one_time_alert("warning",0, *args)
end

# Convenience method for setting 'db' true within methods,
# and to print a one-time warning if so.
# @param val value to set db to; it is convenient to disable
#    debug printing quickly by adding a zero, e.g., 'warndb 0'
#
def warndb(val = true)
  if !val || val == 0
    return false
  end
  one_time_alert("warning",1, "Debug printing enabled")
  true
end

# Print an 'unimplemented' alert, one time only 
# @param args if present, calls printf() with these
def unimp(*args)
  one_time_alert("unimplemented", 0, *args)
end

# Write a string to a text file
#
def write_text_file(path, contents)
    File.open(path, "wb") {|f| f.write(contents) }
end

# Read a file's contents, return as a string
#
def read_text_file(path)
  contents = nil
  File.open(path,"rb") {|f| contents = f.read }
  contents
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

def to_hex(value, num_digits=4) 
  s = sprintf("%x", value)
  s.rjust(num_digits,'0')
end

def hex_dump(byte_array_or_string, title=nil, offset=0, length= -1, bytes_per_row=16, with_text=true) 
  ss = hex_dump_to_string(byte_array_or_string, title, offset, length, bytes_per_row, with_text)
  puts ss
end

def hex_dump_to_string(byte_array_or_string, title=nil, offset=0, length= -1, bytes_per_row=16, with_text=true)
  
  byte_array = byte_array_or_string
  if byte_array.is_a? String
    byte_array = byte_array.bytes.to_a
  end
  
  ss = ''
  
  if title 
    ss << title << ":\n"
  end
  
  if length < 0 
    length = byte_array.size - offset
  end
    
  length = [length, byte_array.size - offset].min
  
  max_addr = offset + length - 1
  num_digits = 4
  while (1 << (4 * num_digits)) <= max_addr
    num_digits += 1
  end
  
  while true
    ss << to_hex(offset, num_digits)
    ss << ': '
    
    chunk = [length, bytes_per_row].min
    bytes_per_row.times do |i|
      if i % 4 == 0 
        ss << '  '
      end
      
      if i < chunk 
        v = byte_array[offset + i]
        ss << ((v != 0) ? to_hex(v,2) : '..')
        ss << ' '
      else
        ss << '   '
      end
  
    end
        
        
    if with_text 
      ss << '  |'
      bytes_per_row.times do |i|
        if i < chunk 
          v = byte_array[offset + i]
          ss << ((v >= 32 && v < 127) ? v : '_')
        end
      end
      ss << '|'
    end
    ss << "\n"
    
    length -= chunk
    offset += chunk
    break if length <= 0
  end
  ss
end

$prevTime = nil

# Calculate time elapsed, in seconds, from last call to this function;
# if it's never been called, returns zero
def elapsed 
  curr = Time.now.to_f
  elap = 0
  if $prevTime
    elap = curr - $prevTime
  end
  $prevTime = curr
  elap
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

require 'stringio'

$IODest = nil
$OldStdOut = nil

def capture_begin
    raise IllegalStateException if $IODest
    $IODest = StringIO.new
    $OldStdOut, $stdout = $stdout, $IODest
end

def capture_end
  raise IllegalStateException if !$IODest
  $stdout = $OldStdOut  
  ret = $IODest.string
  $IODest = nil
  ret
end

def match_expected_output(str = nil)
  
  if !str
    str = capture_end
  end
  
  cl_method = caller[0][/`.*'/][1..-2]
  if (cl_method.start_with?("test_"))
    cl_method = cl_method[5..-1]
  end
  path = "_output_" + cl_method + ".txt"
#  path = File.absolute_path(path)
  
  if !File.file?(path)
    printf("no such file #{path} exists, writing it...\n")
    writeTextFile(path,str)
  else
    exp_cont = readTextFile(path)  
    if str != exp_cont
      d1 = str
      d2 = exp_cont
#      d1 = hex_dump_to_string(str,"Output")
#      d2 = hex_dump_to_string(exp_cont,"Expected")
            
      raise IllegalStateException,"output did not match expected:\n#{d1}#{d2}"
    end
  end
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

# Construct a string from an array of bytes 
# @param byte_array array of bytes, or string (in which case it
#   returns it unchanged)
#
def bytes_to_str(byte_array)
  return byte_array if byte_array.is_a? String
  
  byte_array.pack('C*')
end

# Construct an array of bytes from a string  
# @param str string, or array of bytes (in which case it
#   returns it unchanged)
#
def str_to_bytes(str)
  return str if str.is_a? Array
  str.bytes
end

# Get directory entries, excluding '.' and '..'
#
def dir_entries(path)
  ents = Dir.entries(path)
  ents.reject!{|entry| entry == '.' || entry == '..'}
end

def int_to_bytes(x)
  [(x >> 24) & 0xff, (x >> 16) & 0xff, (x >> 8) & 0xff, x & 0xff]
end
  
def short_to_bytes(x) 
  [(x >> 8) & 0xff, x & 0xff]
end
 
# Decode a short from an array of bytes (big-endian).
# @param ba array of bytes
# @param offset offset of first (most significant) byte
#
def short_from_bytes(ba, offset=0) 
  (ba[offset] << 8) | ba[offset + 1] 
end
    
# Decode an int from an array of bytes (big-endian).
# @param ba array of bytes
# @param offset offset of first (most significant) byte
#
def int_from_bytes(ba, offset=0) 
  (((((ba[offset] << 8) | ba[offset + 1]) << 8) | \
      ba[offset + 2]) << 8) | ba[offset + 3]
end

# Transform string to 8-bit ASCII (i.e., just treat each byte as-is)
#
def to_ascii8(str)
  str.force_encoding("ASCII-8BIT")
end

# Verify that a string is encoded as ASCII-8BIT
def simple_str(s)
  if s.encoding.name != 'ASCII-8BIT' && s.encoding.name != 'UTF-8'
    pr("string [%s]\n encoding is %s,\n expected ASCII-8BIT\n",s,s.encoding.name)
    assert!(false)
  end
end

# Truncate or pad string so it has a particular size
#
# @param s input string
# @param size 
# @param pad padding character to use if string needs to grow
# @return modified string
#
def str_sized(s, size, pad="\0")
  s[0...size].ljust(size,pad)
end

# Determine if running on the Windows operating system.
# Note: there is some debate about the best way to do this.
#
def windows?
  if !defined? $__windows__
    $__windows__ = (RUBY_PLATFORM =~ /mswin/)
  end
  $__windows__
end

# Mark all constants ending with '_' as private constants
#
# @param entity the class to examine
# @param add_non_suffix_versions if true, for each constant ABC_ found, also
#    defines a constant ABC with the same value that is also private
#
def privatize(entity, add_non_suffix_versions = false)
  
  db = false
  
  # First command defines constants ABC = n for each constant ABC_ = n;
  # Second declares both versions to be private
  
  cmd1 = nil
  cmd2 = nil
  
  entity.constants.each do |c|
    nm = c.to_s
    
    if nm.end_with?('_')
      nm_small = nm[0..-2]
      
      if !cmd2
        if add_non_suffix_versions
          cmd1 = ''
        end
        cmd2 = 'private_constant '
      else
        cmd2 << ','
      end 
      
      
      !cmd1 || cmd1 << entity.to_s << '::' << nm_small << '=' << entity.const_get(c).to_s << "\n"
      !cmd1 || cmd2 << ':' << nm_small << ','
      cmd2 << ':' << nm
    end
  end
  
  if cmd2
     if cmd1
       !db || pr("about to eval:\n%s\n",cmd1)
       eval(cmd1)
     end
     !db || pr("about to eval:\n%s\n",cmd2)
     eval(cmd2)
  end
end
