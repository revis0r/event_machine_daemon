# 
# Класс сервера для EventMachine
# 
# @author  Ivan Goncharov
class Directory::Server < EM::Connection
  # Старт сервера.
  # Загружает конфиги, устанавливает переменные и т.д.
  def initialize
    debug "Starting Directory Server."
    # Устанавливаем переменные
    @debug = true
    @arel = Person.arel_table
  end

  def post_init
    debug "[!] Connection accepted!"
  end

  # 
  # Колбэк на получение данных
  # @param data [String] данные
  # 
  # @return [Array] полученный пакет
  def receive_data data
    close_connection if data =~ /quit/i
    operation = Proc.new do
      data = data.strip
      # Анонимная функция операции
      # Выполняет поиск клиента в базе
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

    # Колбэк после выполнения операции.
    # Принимает на вход то, что вернул operation.
    # Генерирует ответ, и возвращает его клиенту.
    callback = Proc.new do |r|
      send(r)
    end

    EM.defer operation, callback
  end

  def unbind
    debug 'Connection closed'
  end

  private

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
