begin
  require 'daemons'
rescue LoadError
  raise "You need to add gem 'daemons' to your Gemfile if you wish to use it."
end
require 'optparse'
require_relative './server'

# 
# Control class for Directory-server.
# Parse arguments, configure and start server
module Directory
  class Command
    # 
    # Constructor. Parse arguments passed from console
    # @param args [Array] console arguments ARGV
    # 
    # @return [Directory::Command] object of class
    def initialize(args)
      @options = {
        :quiet => true,
        :pid_dir => "#{Rails.root}/tmp/pids",
        :address => '127.0.0.1',
        :port => 31337
      }

      @monitor = false

      opts = OptionParser.new do |opt|
        opt.banner = "Usage: directory [options] start|stop|restart|run"

        opt.on('-a', '--address=127.0.0.1', 'Host to bind server') do |address|
          @options[:address] = address
        end
        opt.on('-p', '--port=31337', 'Port to bind server') do |n|
          @options[:port] = n.to_i
        end
        opt.on_tail('-h', '--help', 'Show this message') do
          puts opt
          exit 1
        end
      end
      @args = opts.parse!(args)
    end

    # 
    # Daemonize of server
    def daemonize
      dir = @options[:pid_dir]
      Dir.mkdir(dir) unless File.exist?(dir)
      run_process('directory_server', @options)
    end

    # 
    # Run process
    # @param process_name [String] name of process
    # @param options [Hash] options
    def run_process(process_name, options = {})
      Daemons.run_proc(process_name, :dir => options[:pid_dir], :dir_mode => :normal, :monitor => @monitor, :ARGV => @args) do |*_args|
        $0 = File.join(options[:prefix], process_name) if @options[:prefix]
        run process_name, options
      end
    end

    # 
    # Start EventMachine
    # @param worker_name [String] name of process
    # @param options [Hash] options
    def run(worker_name = nil, options = {})
      Dir.chdir(Rails.root)

      Rails.logger = Logger.new(File.join(Rails.root, 'log', 'directory_server.log'))
      EventMachine::run do
        EventMachine::start_server(options[:address], options[:port].to_i, Directory::Server)
      end
    rescue => e
      Rails.logger.fatal e
      STDERR.puts e.message
      exit 1
    end
    
  end
end