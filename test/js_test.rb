require "minitest/autorun"
require "open3"
require "stringio"
require "tempfile"

class IOOutputCapture < StringIO

  attr_accessor :echo, :content_buffer

  DASHES = ('-' * 130)

  def initialize(echo, content_buffer, channel_flag, for_errors)
    self.echo = echo
    self.content_buffer = content_buffer
    @channel_flag = channel_flag
    @for_errors = for_errors
    @actual_output = for_errors ? $stderr : $stdout
  end

  def print_interleave_transition
    if @for_errors != @channel_flag[0]
      msg = ''
      msg << "\n" if !self.content_buffer.string.end_with?("\n")
      msg << '-'*30
      msg << (@for_errors ? '<stderr>' : '<stdout>')
      msg << '-'*30
      msg << "\n"
      @actual_output.write(msg) if self.echo
      self.content_buffer.write(msg)
      @channel_flag[0] = @for_errors
    end
  end

  def putc(value)
    print_interleave_transition
    @actual_output.putc(value) if self.echo
    self.content_buffer.putc(value)
  end

  def write(str)
    print_interleave_transition
    @actual_output.write(str) if self.echo
    self.content_buffer.write(str)
  end

  def flush
    self.content_buffer.flush
  end

  def close
    self.flush
  end

  def string
    self.content_buffer.string
  end

  def tty?
    false
  end

end

class IOCapture

  attr_accessor :echo

  # This is where the captured output will be written to
  attr_accessor :content_buffer

  attr_accessor :is_open

  def initialize
    self.echo = false
    self.content_buffer = StringIO.new
    self.is_open = false
  end

  def open
    raise("already open") if self.is_open
    self.is_open = true
    # Construct substitutes for stdout and stderr, that will write to our content buffer
    our_stderr_flag = [false]
    @my_stdout = IOOutputCapture.new(self.echo,self.content_buffer,our_stderr_flag, false)
    @my_stderr = IOOutputCapture.new(self.echo,self.content_buffer,our_stderr_flag, true)
    @saved_stdout = $stdout
    @saved_stderr = $stderr
    $stdout = @my_stdout
    $stderr = @my_stderr
  end

  def close
    if (self.is_open)
      $stdout = @saved_stdout
      $stderr = @saved_stderr
      @my_stdout.close
      self.is_open = false
    end
  end

  def output_content
    raise("IOCapture is still open") if self.is_open
    self.content_buffer.string
  end

end


# TestSnapshot class
#
# Uses IOCapture class to capture program output,
# and to save as testing snapshot, and report errors if existing
# snapshots exist and are different.
#

# Exception class for snapshot disagreeing with reference version
#
class TestSnapshotException < Exception; end

class TestSnapshot

  attr_reader :user_input_path, :output_path

  def initialize(path_prefix = nil)
    @iocapture = nil
    @temp_file = nil

    # Look for a calling method that starts with 'test_' prefix
    caller_loc = caller_locations(0)
    index = 0
    while true
      if index >= caller_loc.size
        raise Exception,"Must supply a path prefix"
      end

      caller_method = caller_loc[index]
      this_path_prefix = caller_method.label
      break if this_path_prefix.start_with?('test_')
      index += 1
    end

    # Determine script containing caller method
    caller_path = caller_method.absolute_path
    caller_file = File.basename(caller_path,'.rb')

    if !path_prefix
      path_prefix = this_path_prefix
    end
    @path_prefix = path_prefix

    @snapshot_basename = "_snapshots_[#{caller_file}]_"
    @snapshot_subdir = File.join(File.dirname(caller_path),@snapshot_basename)
  end

  def perform(replace_existing_snapshot=false, &block)
    @replace_existing_snapshot = replace_existing_snapshot
    setup
    completed = false
    begin
      yield
      completed = true
    ensure
      teardown(completed)
    end
  end


  private


  def setup
    calculate_paths()
    @recording = @replace_existing_snapshot || !File.exist?(@reference_path)

    @iocapture = IOCapture.new
    @iocapture.echo = @recording
    @iocapture.open
  end

  def teardown(completed)

    @iocapture.close

    if completed

      if @recording

        # Write output

        output_content = @iocapture.output_content

        # Print warning if existing snapshot changed
        if @replace_existing_snapshot
          existing = File.read(@reference_path)
          if (existing && output_content != existing)
            puts "...snapshot changed: #{@reference_path}"
          end
        end

        File.write(@reference_path,output_content)

      else

        # Not implemented: verify that we used the entire input script

        @temp_file = Tempfile.new('io_recorder')
        File.write(@temp_file.path,@iocapture.output_content)
        compare_reference_and_snapshot
      end
    else
      puts "\n(Failed to complete TestSnapshot task: #{@path_prefix})"
    end
  end

  def calculate_paths
    # If no _snapshot_ subdirectory exists, create it
    Dir.mkdir(@snapshot_subdir) if !File.directory?(@snapshot_subdir)
    @user_input_path = File.join(@snapshot_subdir,@path_prefix + '_input.txt')
    @reference_path = File.join(@snapshot_subdir,@path_prefix + '_reference.txt')
  end

  def compare_reference_and_snapshot(assert_if_mismatch = true)
    difference = calc_diff(@reference_path,@temp_file.path)
    if assert_if_mismatch
      if difference
        lines = "\n" + ('-' * 130) + "\n"
        raise TestSnapshotException,"Output does not match reference file #{@snapshot_basename}/#{@path_prefix}:" \
        + lines + difference.chomp + lines
      end
    end
    difference == nil
  end

  def calc_diff(path1=nil, path2=nil)
    df,_ = scall("diff -C 1 \"#{path1}\" \"#{path2}\"", false)
    if df.size == 0
      nil
    else
      # If difference was detected, call with more user-friendly output
      df,_ = scall("diff --width=130 -y \"#{path1}\" \"#{path2}\"", false)
      df
    end
  end

  # Make a system call
  #
  # @param cmd command to execute
  # @param abort_if_problem if return code is nonzero, raises SystemCallException
  # @return [captured output, success flag] (where success is true if return code was zero)
  #
  def scall(cmd, abort_if_problem = true)
    res = nil
    status = false
    begin
      res,status = Open3.capture2e(cmd)
    rescue Exception => e
      status = 1
      res = e.to_s
    end

    success = (status == 0)

    if !success && abort_if_problem
      raise SystemCallException,"Failed system call (status=#{status}): '#{cmd}'\n"+res
    end

    [res, success]
  end


end



class SysCall

  def initialize(command)
    @command = command
    @output = nil
    @dir = nil
    @hide_output = false
    @hide_command = false
    @dryrun = false
  end

  def hide_command(flag = true)
    @hide_command = flag
    self
  end

  def hide(flag = true)
    @hide_output = flag
    hide_command(flag)
  end

  def with_dryrun
    @dryrun = true
    self
  end

  def with_rescue
    @rescue = true
    self
  end

  def with_verbose(verbose = true)
    @verbose = verbose
    self
  end

  def dryrun
    @dryrun
  end

  def command
    @command
  end

  def exception
    @exception
  end

  def within_dir(dir)
    @dir = dir
    self
  end

  def call
    return @output unless @output.nil?

    eff_cmd = command
    if @dir
      eff_cmd = "cd #{@dir}; #{eff_cmd}"
    end

    unless @hide_command
      expr = "\n> "
      expr << "...dry run: " if dryrun
      expr << eff_cmd
      puts expr
    end

    @output = ""
    @exception = nil

    if !dryrun
      begin
        Open3.popen2e(eff_cmd) do |stdin, stdout_err, wait_thr|
          while line = stdout_err.gets
            @output << line
            print line unless @hide_output
          end

          exit_status = wait_thr.value
          @success = exit_status.success?
          if !@success
            raise eff_cmd
          end
        end
      rescue => @exception
      end
    end

    if @exception
      puts("...exception: #{@exception}") unless @hide_output
      raise @exception unless @rescue
    end

    @output
  end

  def output
    call
  end

  def success
    call
    @success
  end

  def to_s
    m = {}
    m["command"] = @command if @command
    m["exception"] = @exception if @exception
    m["output"] = @output if @output
    pretty_pr(m)
  end

end








class JSTest < Minitest::Test


  def setup
    super
    @original_directory = nil
    @test_dir = nil
    @saved_stdout = nil
  end

  def teardown
    leave_test_directory if @original_directory
    super
  end

  # Create a temporary subdirectory for test purposes, and make it the current directory.
  #
  # @param subdirectory_name the name of the subdirector(ies) to create,
  #  as a subdirectory of the calling script's directory; if nil, derives it from
  #  the calling script's name.
  #
  def enter_test_directory(subdirectory_name = nil)
    c = caller()[0]
    c = c[0...c.index(':')]
    script_path = File.dirname(c)
    if !subdirectory_name
      subdirectory_name = File.basename(c,'.rb')
      if subdirectory_name.start_with? 'test_'
        subdirectory_name.slice!(0...5)
      end
      subdirectory_name.insert(0,'temporary_')
    end

    @test_dir = File.join(script_path,subdirectory_name)
    FileUtils.mkdir_p(@test_dir)

    @original_directory = Dir.pwd
    Dir.chdir(@test_dir)
  end

  # Restore the original directory, and optionally delete the test directory
  #
  def leave_test_directory(retain = false)
    raise IllegalStateException, "No test directory found" if !@original_directory
    Dir.chdir(@original_directory)
    @original_directory = nil
    FileUtils.rm_rf(@test_dir) if !retain
  end

  # Generate hierarchy of text files
  # script : a hash of string(filename) => string(text file contents) or hash (subdirectory)
  #
  def generate_files(base_dir,script,mtime=nil)

    base_dir ||= Dir.pwd

    script.each_pair do |filename,value|
      path = File.join(base_dir,filename)
      if value.instance_of? Hash
        FileUtils.mkdir_p(path)
        if mtime
          File.utime(mtime,mtime,path)
        end
        generate_files(path,value,mtime)
      else
        File.write(path,value)
        if mtime
          File.utime(mtime,mtime,path)
        end
      end
    end
  end

  # Redirect stdout to a string buffer
  #
  def redirect_stdout
    raise IllegalStateException, "Already redirected" if @saved_stdout
    @saved_stdout = $stdout
    $stdout = StringIO.new
  end

  # Restore stdout, if it was previously redirected; return
  # the text that was redirected, or nil if it wasn't redirected
  #
  def restore_stdout
    content = nil
    if @saved_stdout
      @saved_stdout.flush
      content = $stdout.string
      $stdout = @saved_stdout
      @saved_stdout = nil
    end
    content
  end

end
