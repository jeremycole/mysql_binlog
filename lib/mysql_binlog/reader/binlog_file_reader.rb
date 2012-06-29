module MysqlBinlog
  # Read a binary log from a file on disk.
  class BinlogFileReader
    def initialize(filename)
      @filename = filename
      @binlog = nil
      
      open_file(filename)
    end

    def open_file(filename)
      @filename = filename
      @binlog = File.open(filename, mode="r")

      if (magic = read(4).unpack("V").first) != 1852400382
        raise MalformedBinlogException.new("Magic number #{magic} is incorrect")
      end
    end

    def rotate(filename, position)
      open_file(filename)
      seek(position)
    end

    def filename
      @filename
    end

    def position
      @binlog.tell
    end

    def rewind
      @binlog.rewind
    end

    def seek(pos)
      @binlog.seek(pos)
    end
  
    def end?
      @binlog.eof?
    end

    def remaining(header)
      header[:next_position] - @binlog.tell
    end

    def skip(header)
      seek(header[:next_position])
    end

    def read(length)
      return "" if length == 0
      data = @binlog.read(length)
      if !data
        raise MalformedBinlogException.new
      elsif data.length == 0
        raise ZeroReadException.new
      elsif data.length < length
        raise ShortReadException.new
      end
      data
    end
  end
end