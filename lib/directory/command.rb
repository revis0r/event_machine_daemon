begin
  require 'daemons'
rescue LoadError
  raise "You need to add gem 'daemons' to your Gemfile if you wish to use it."
end
require 'optparse'
require_relative './server'

# 
# Класс для управления Directory-сервером.
# Разбирает входные параметры, настраивает и запускает сервер
# 
# @author  Ivan Goncharov
module Directory
  class Command
    # 
    # Конструктор. Разбирает переданные параметры
    # @param args [Array] параметры командной строки ARGV
    # 
    # @return [Directory::Command] объект класса
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
    # Демонизация класса
    def daemonize
      dir = @options[:pid_dir]
      Dir.mkdir(dir) unless File.exist?(dir)
      run_process('directory_server', @options)
    end

    # 
    # Запуск процесса
    # @param process_name [String] имя процесса
    # @param options [Hash] опции
    def run_process(process_name, options = {})
      Daemons.run_proc(process_name, :dir => options[:pid_dir], :dir_mode => :normal, :monitor => @monitor, :ARGV => @args) do |*_args|
        $0 = File.join(options[:prefix], process_name) if @options[:prefix]
        run process_name, options
      end
    end

    # 
    # Запуск EventMachine
    # @param worker_name [String] имя процесса
    # @param options [Hash] опции
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