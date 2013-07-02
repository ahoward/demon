# -*- encoding : utf-8 -*-
 
class Demon
  Version = '0.0.666' unless defined?(Version)
  Load = Kernel.method(:load) unless defined?(Load)

  class << Demon
    def version
      Demon::Version
    end

    def libdir(*args, &block)
      @libdir ||= File.expand_path(__FILE__).sub(/\.rb$/,'')
      libdir = args.empty? ? @libdir : File.join(@libdir, *args.map{|arg| arg.to_s})
    ensure
      if block
        begin
          $LOAD_PATH.unshift(libdir) unless $LOAD_PATH.first==libdir
          module_eval(&block)
        ensure
          $LOAD_PATH.shift() if $LOAD_PATH.first==libdir
        end
      end
    end

    def load(*args, &block)
      libdir{ Load.call(*args, &block) }
    end

    def dependencies
      {
        'map'               => [ 'map'               , ' >= 6.0.0' ]
      }
    end
  end

  begin
    require 'rubygems'
  rescue LoadError
    nil
  end

  begin
    require 'logging'
  rescue LoadError
    nil
  end

  if defined?(gem)
    Demon.dependencies.each do |lib, dependency|
      gem(*dependency)
      require(lib)
    end
  end

  require 'fileutils'
  require 'ostruct'
  require 'rbconfig'
  require 'pathname'
  require 'logger'
  require 'yaml'
end


class Demon
  def initialize(*args, &block)
  #
    @options =  Map.extract_options!(args)

  #
    @__file__ = (
      @options[:script] or
      @options[:file] or
      @options[:__file__] or
      args.shift or
      (block ? eval('File.expand_path(__FILE__)', block.binding) : nil)
    )
    raise("no __FILE__ groked!") unless @__file__

    @root = @options[:root]

    @mode = @options[:mode]

  #
    @script = File.expand_path(@__file__)
    raise("no script groked!") unless test(?s, @script)

  #
    @cmdline = generate_cmdline

    @dirname = File.expand_path(File.dirname(@script))
    @basename = File.basename(@script)

    @script_root = File.expand_path(File.dirname(@script))

  #
    rails_root = @script_root
    seems_to_be_a_rails_app = false

    42.times do
      seems_to_be_a_rails_app =
        %w( app/controllers app/models app/views config Rakefile ).all? do |subdir|
          test(?e, File.join(rails_root, subdir))
        end

      if seems_to_be_a_rails_app or rails_root == '/'
        break
      end

      rails_root = File.expand_path(File.dirname(rails_root))
    end

    if seems_to_be_a_rails_app
      @rails_root = rails_root

      @demon_dir = File.join(@rails_root, 'log', 'demon')
      @restart_txt = File.join(@rails_root, 'tmp', 'restart.txt')

      self.prefix = File.join(@demon_dir, @basename)

      @root = @rails_root
    else
      @rails_root = false

      @demon_dir = @root || "#{ @script }.demon"
      @restart_txt = File.join(@demon_dir, 'restart.txt')

      self.prefix = @demon_dir

      @root = @demon_dir
    end

  #
    @signals    = []
    @started_at = Time.now
    @sleeping   = false
    @ppid       = Process.pid

  #
    STDOUT.sync = true
    STDERR.sync = true

    self
  end

  def prefix
    @prefix
  end

  def prefix=(prefix)
    @prefix = File.expand_path(prefix.to_s)

    @lock_file    = File.join(@prefix, 'lock')
    @log_file     = File.join(@prefix, 'log')
    @pid_file     = File.join(@prefix, 'pid')
    @cmdline_file = File.join(@prefix, 'cmdline')
    @stdin_file   = File.join(@prefix, 'stdin')
    @stdout_file  = File.join(@prefix, 'stdout')
    @stderr_file  = File.join(@prefix, 'stderr')

    FileUtils.mkdir_p(@prefix)

    %w( lock log pid cmdline stdin stdout stderr ).each do |which|
      file = instance_variable_get("@#{ which }_file")
      FileUtils.touch(file)
    end

    @prefix
  end

  %w(

    script
    mode
    dirname
    basename
    root
    script_root
    rails_root
    prefix
    basename_dir
    lock_file
    log_file
    pid_file
    cmdline_file
    restart_txt
    started_at
    signals

  ).each{|a| attr(a)}

  def start(which = :start, &block)
    mode = "mode_#{ which }".downcase
    send(mode) if respond_to?(mode)
    run_forever_handling_signals_and_logging_errors!(&block)
  end

  def Demon.start(*args, &block)
    new(*args).tap{|demon| demon.start(&block)}
  end

  def run(which = :run, &block)
    mode = "mode_#{ which }".downcase
    send(mode) if respond_to?(mode)
    run_forever_handling_signals_and_logging_errors!(&block)
  end

  def Demon.run(*args, &block)
    new(*args).tap{|demon| demon.run(&block)}
  end

  module ::Kernel
    def Demon(*args, &block)
      demon = ::Demon.new(*args, &block)
      mode = demon.mode || ARGV[0] || :run
      demon.run(mode, &block)
    end
  end

  def run_forever_handling_signals_and_logging_errors!(&block)
    loop do
      catch(:signals) do
        process_signals

        begin
          block.call() if block
        rescue => e
          logger.error(e)
        ensure
          wait(420) unless $! # NOTE: signals wake this up!
        end
      end
    end
  end

  def Demon.modes
    instance_methods.grep(/mode_(.*)/).map{|mode| mode.to_s.split('_').last}
  end

  def mode_modes
    puts Demon.modes.join('|')
    exit(42)
  end

  def Demon.help
    {
      'start'   => 'start in daemon mode',
      'run'     => 'run in the foreground, but otherwise like a daemon',
      'stop'    => 'stop any currently running daemon',
      'restart' => 'restart any currently running daemon, or start a new one',
      'pid'     => 'print the pid of the running daemon, iff any',
      'ping'    => 'ensure a daemon is running, start one iff not',
      'signal'  => 'hit the daemon, if any, with SIGUSR2',
      'tail'    => 'tail -F all auxillary files (lock files, logs, etc)',
      'fuser'   => 'report the fuser of any auxillary files (lock files, logs, etc)',
      'log'     => 'display the location of the log file',
      'root'    => 'display the location of the root daemon dir (lock files, logs, etc)',
      'modes'   => 'print all modes, even those without "help"',
      'help'    => 'this message'
    }
  end

  def mode_help
    puts(Demon.help.to_yaml)
    exit(42)
  end

  def mode_ping
    pid = Integer(IO.read(@pid_file)) rescue nil

    if pid
      signaled = false

      begin
        Process.kill('SIGALRM', pid)
        signaled = true
      rescue Object
        nil
      end

      if signaled
        STDOUT.puts(pid)
        exit
      end
    end

    Kernel.exec("#{ @script } start")
  end

  def mode_run
    lock!(:complain => true)

    pid!

    cmdline!

    trap!

    boot!

    logging!

    log!
  end

  def mode_start
    lock!(:complain => true)

    daemonize!{|pid| puts(pid)}

    redirect_io!

    pid!

    cmdline!

    trap!

    boot!

    logging!

    signal_if_redeployed!

    log!
  end

  def mode_restart
    begin
      pid = Integer(IO.read(@pid_file)) rescue nil
      Process.kill('HUP', pid)
      puts "Process #{pid} signaled to restart"
      exit(0)
    rescue
      puts "No running process found. Starting a new one."
      mode_start
    end
  end

  def mode_pid
    pid = Integer(IO.read(@pid_file)) rescue nil
    if pid
      begin
        Process.kill(0, pid)
        puts(pid)
        exit(0)
      rescue Errno::ESRCH
        exit(1)
      end
    else
      exit(1)
    end
    exit(1)
  end

  def mode_fuser
    exec("fuser #{ @lock_file.inspect }")
  end

  def mode_stop
    pid = Integer(IO.read(@pid_file)) rescue nil
    if pid
      alive = true

      %w( QUIT TERM ).each do |signal|
        begin
          Process.kill(signal, pid)
        rescue Errno::ESRCH
          nil
        end

        42.times do
          begin
            Process.kill(0, pid)
            sleep(rand)
          rescue Errno::ESRCH
            alive = false
            puts(pid)
            exit(0)
          end
        end
      end

      if alive
        begin
          Process.kill(-9, pid)
          sleep(rand)
        rescue Errno::ESRCH
          nil
        end

        begin
          Process.kill(0, pid)
        rescue Errno::ESRCH
          puts(pid)
          exit(0)
        end
      end
    end
    exit(1)
  end

  def mode_signal(signal = 'SIGUSR2')
    pid = Integer(IO.read(@pid_file)) rescue nil
    if pid
      Process.kill(signal, pid)
      puts(pid)
      exit(0)
    end
    exit(42)
  end

  def mode_log
    puts(@log_file)
    exit(42)
  end

  def mode_root
    puts(@root)
    exit(42)
  end

  def mode_tail
    system("tail -F #{ @stdout_file.inspect } #{ @stderr_file.inspect } #{ @log_file.inspect }")
    exit(42)
  end


  def process_signals
    if signaled?
      signals.uniq.each do |signal|
        case signal.to_s
          when /HUP/i
            logger.info('RESTART - signal')
            restart!
          when /USR1/i
            logger.info('RESTART - deploy')
            restart!
          when /USR2/i
            nil
          when /ALRM/i
            nil
        end
      end
      signals.clear
    end
  end

  def wait(seconds)
    begin
      @sleeping = true
      Kernel.sleep(seconds)
    ensure
      @sleeping = false
    end
  end

  def restart!
    exit!(0) if fork

    logger.info('CMD - %s' % Array(@cmdline).join(' '))

    unlock!

    keep_ios(STDIN, STDOUT, STDERR)

    Kernel.exec(*@cmdline)
  end

  def boot!
    if @rails_root
      Dir.chdir(@rails_root)
      require File.join(@rails_root, 'config', 'boot')
      require File.join(@rails_root, 'config', 'environment')
    end
  end

  def lock!(options = {})
    complain = options['complain'] || options[:complain]
    fd = open(@lock_file, 'r+')
    status = fd.flock(File::LOCK_EX|File::LOCK_NB)

    unless status == 0
      if complain
        pid = Integer(IO.read(@pid_file)) rescue '?'
        warn("instance(#{ pid }) is already running!")
      end
      exit(42)
    end
    @lock = fd # prevent garbage collection from closing the file!
    at_exit{ unlock! }
  end

  def unlock!
    @lock.flock(File::LOCK_UN|File::LOCK_NB) if @lock
  end

  def pid!
    open(@pid_file, 'w+') do |fd|
      fd.puts(Process.pid)
    end
    at_exit{ FileUtils.rm_f(@pid_file) }
  end

  def cmdline!
    open(@cmdline_file, 'w+') do |fd|
      fd.puts(Array(@cmdline).join(' '))
    end
  end

  def trap!
    %w( SIGHUP SIGALRM SIGUSR1 SIGUSR2 ).each do |signal|
      trap(signal) do |sig|
        signals.push(signal)
        logger.debug("SIGNAL - #{ signal }")
        throw(:signals, signal) if sleeping?
      end
    end

    trap('SIGQUIT'){ exit(42) }
    trap('SIGTERM'){ exit(42) }
    trap('SIGINT'){ exit(42) }
  end

  def signal_if_redeployed!
    seconds = production? ? 10 : 1

    Thread.new do
      Thread.current.abort_on_exception = true
      loop do
        Kernel.sleep(seconds)
        Process.kill(:USR1, Process.pid) if redeployed?
      end
    end
  end

  def log!
    logger.info("START - #{ Process.pid }")
    at_exit do
      logger.info("STOP - #{ Process.pid }") rescue nil
    end
  end

  def redeployed?
    t = File.stat(current_path_for(@restart_txt)).mtime rescue @started_at
    t > @started_at
  end

  def generate_cmdline
    current_script = current_path_for(@script)
    [which_ruby, current_script, 'start']
  end

  def current_path_for(path)
    path.to_s.gsub(%r|\breleases/\d+\b|, 'current')
  end

  def which_ruby
    c = ::RbConfig::CONFIG
    ruby = File::join(c['bindir'], c['ruby_install_name']) << c['EXEEXT']
    raise "ruby @ #{ ruby } not executable!?" unless test(?e, ruby)
    ruby
  end

  def cap?(&block)
    realpath = proc do |path|
      begin
        (path.is_a?(Pathname) ? path : Pathname.new(path.to_s)).realpath.to_s
      rescue Errno::ENOENT
        nil
      end
    end

    cap_root = realpath[@rails_root || @root]

    shared_path = File.expand_path('../../shared', cap_root)
    cap_path = File.dirname(shared_path)
    shared_public_system_path = File.expand_path('../../shared/system')
    public_path = File.join(cap_root, 'public')

    public_system_path = File.join(public_path.to_s, 'system')
 
    is_cap_deploy =
      test(?e, shared_public_system_path) and
      test(?l, public_system_path) and
      realpath[shared_public_system_path] == realpath[public_system_path]

    return false unless is_cap_deploy

    args = 
      if block
        [cap_path].slice(block.arity > 0 ? (0 ... block.arity) : (0 .. -1))
      else
        []
      end
    block ? block.call(*args) : cap_path
  end

  def production?
    if defined?(Rails.env)
      Rails.env.production?
    else
      true
    end
  end

  def sleeping?(&block)
    if block
      block.call if @sleeping
    else
      @sleeping == true
    end
  end

  def signaled?
    !signals.empty?
  end

  def logger
    @logger ||= (
      require 'logger' unless defined?(Logger)
      Logger.new(STDERR)
    )
  end

  def logger=(logger)
    @logger = logger
  end

  def logging_errors(&block)
    begin
      block.call()
    rescue SignalException => e
      logger.info(e)
      exit(0)
    rescue => e
      logger.error(e)
    end
  end


# daemonize{|pid| puts "the pid of the daemon is #{ pid }"}
#

  def daemonize!(options = {}, &block)
  # optional directory and umask
  #
    chdir = options[:chdir] || options['chdir'] || '.'
    umask = options[:umask] || options['umask'] || 0

  # drop to the background avoiding the possibility of zombies..
  #
    detach!(&block)

  # close all open io handles *except* these ones
  #
    keep_ios(STDIN, STDOUT, STDERR, @lock)

  # sane directory and umask
  #
    Dir::chdir(chdir)
    File::umask(umask)

  # global daemon flag
  #
    $DAEMON = true
  end

  def detach!(&block)
  # setup a pipe to relay the grandchild pid through
  #
    a, b = IO.pipe

  # in the parent we wait for the pid, wait on our child to avoid zombies, and
  # then exit
  #
    if fork
      b.close
      pid = Integer(a.read.strip)
      a.close
      block.call(pid) if block
      Process.waitall
      exit!
    end

  # the child simply exits so it can be reaped - avoiding zombies.  the pipes
  # are inherited in the grandchild
  #
    if fork
      exit!
    end

  # finally, the grandchild sends it's pid back up the pipe to the parent is
  # aware of the pid
  #
    a.close
    b.puts(Process.pid)
    b.close

  # might as well nohup too...
  #
    Process::setsid rescue nil
  end

  def redirect_io!(options = {})
    stdin = options[:stdin] || @stdin_file
    stdout = options[:stdout] || @stdout_file
    stderr = options[:stderr] || @stderr_file

    {
      STDIN => stdin, STDOUT => stdout, STDERR => stderr
    }.each do |io, file|
      opened = false

      fd =
        case
          when file.is_a?(IO)
            file
          when file.to_s == 'null'
            opened = true
            open('/dev/null', 'ab+')
          else
            opened = true
            open(file, 'ab+')
        end

      begin
        fd.sync = true rescue nil
        fd.truncate(0) rescue nil
        io.reopen(fd)
      ensure
        fd.close rescue nil if opened
      end
    end
  end

  def logging!
    number_rolled = 7
    megabytes     = 2 ** 20
    max_size      = 42 * megabytes

    @logger =
      if STDIN.tty?
        if defined?(Logging)
          ::Logging.logger(STDERR)
        else
          ::Logger.new(STDERR)
        end
      else
        if defined?(Logging)
          options = defined?(Lockfile) ? {:safe => true} : {}
          ::Logging.logger(@log_file, number_rolled, max_size, options)
        else
          ::Logger.new(@log_file, number_rolled, max_size)
        end
      end

    @logger.level = ::Logger::INFO rescue nil if production?
    @logger.level = ::Logger::DEBUG if STDERR.tty?

    @logger
  end

  def keep_ios(*ios)
    filenos = []

    ios.flatten.compact.each do |io|
      begin
        fileno = io.respond_to?(:fileno) ? io.fileno : Integer(io)
        filenos.push(fileno)
      rescue Object
        next
      end
    end

    ObjectSpace.each_object(IO) do |io|
      begin
        fileno = io.fileno
        next if filenos.include?(fileno)
        io.close unless io.closed?
      rescue Object
        next
      end
    end
  end
end
