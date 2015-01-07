# 
# EventMachine directory server
# 
class Directory::Server < EM::Connection
  # Starting of server.
  # Load configuration, set variables, etc.
  def initialize
    debug "Starting Directory Server."
    # Set variables
    @debug = true
    @arel = Person.arel_table
  end

  # 
  # Callback on accept connection
  # 
  def post_init
    debug "[!] Connection accepted!"
  end

  # 
  # Callback on receive data
  # @param data [String] data
  # 
  # @return [Array] received data
  def receive_data data
    close_connection if data =~ /quit/i
    EM.defer Proc.new{ process_request(data) }, Proc.new { |r| send(r) }
  end

  # 
  # Callback on close connection
  # 
  def unbind
    debug 'Connection closed'
  end

  private

    # 
    # Our "long-running operation".
    # Search person by name
    # 
    # @param data [String] received name
    # 
    # @return [String] result of searching
    def process_request data
      data = data.strip
      begin
        raise "Empty query" unless data.present?
        query_string = "%#{data}%"
        people = Person.where(@arel[:name].matches(query_string)).to_a
        ActiveRecord::Base.connection_pool.release_connection
        if people.present?
          debug "[+] Founded #{people.count} people by query: \"#{data}\""
          "[+] " + people.map{|p| "#{p.name}: #{p.phone}"}.join("\n")
        else
          debug "[-] Not found people by query: \"#{data}\""
          "[-] Not found"
        end
      rescue Exception => e
        error "[!] Exception"
        error e.message
        error e.backtrace.inspect
        "[-] " + e.message
      end    
    end

    # 
    # Send data to client
    # @param data [String] response string
    def send(data)
      send_data(data+"\n")
    end

    def debug(text)
      Rails.logger.warn(text) if @debug
    end

    def error(text)
      Rails.logger.fatal(text)
    end

end
