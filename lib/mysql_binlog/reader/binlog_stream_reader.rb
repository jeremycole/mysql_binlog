module MysqlBinlog
  class BinlogStreamReader
    def initialize(connection, filename, position)
      require 'mysql_binlog_dump'
      @filename = nil
      @position = nil
      @packet_data = nil
      @packet_pos  = nil
      @connection = connection
      MysqlBinlogDump.binlog_dump(connection, filename, position)
    end

    def rotate(filename, position)
      puts "rotate called with #{filename}:#{position}"
      @filename = filename
      @position = position
    end

    def filename
      @filename
    end
    
    def position
      @position
    end

    def rewind
      false
    end

    def tell
      @packet_pos
    end

    def end?
      false
    end

    def remaining(header)
      @packet_data.length - @packet_pos
    end

    def skip(header)
      @packet_data = nil
      @packet_pos  = nil
    end

    def read_packet
      @packet_data = MysqlBinlogDump.next_packet(@connection)
      @packet_pos  = 0
    end

    def read(length)
      unless @packet_data
        read_packet
        return nil unless @packet_data
      end
      pos = @packet_pos
      @position   += length if @position
      @packet_pos += length
      @packet_data[pos...(pos+length)]
    end
  end
end