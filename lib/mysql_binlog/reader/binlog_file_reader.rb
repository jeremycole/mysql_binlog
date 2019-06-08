module MysqlBinlog
  # Read a binary log from a file on disk.
  class BinlogFileReader
    MAGIC_SIZE  = 4
    MAGIC_VALUE = 1852400382

    attr_accessor :tail

    def initialize(filename)
      @tail = false
      open_file(filename)
    end

    def verify_magic
      if (magic = read(MAGIC_SIZE).unpack("V").first) != MAGIC_VALUE
        raise MalformedBinlogException.new("Magic number #{magic} is incorrect")
      end
    end

    def open_file(filename)
      @dirname  = File.dirname(filename)
      @filename = File.basename(filename)
      @binlog   = File.open(filename, "r:BINARY")

      verify_magic
    end

    def rotate(filename, position)
      retries = 10
      begin
        open_file(@dirname + "/" + filename)
        seek(position)
      rescue Errno::ENOENT
        # A rotate event will be seen in the previous log file before the
        # new file exists. Retry a few times with a little sleep to give
        # the server a chance to create the new file.
        if (retries -= 1) > 0
          sleep 0.01
          retry
        else
          raise
        end
      end
    end

    def filename
      @filename
    end

    def position
      @binlog.tell
    end

    def rewind
      seek(MAGIC_SIZE)
    end

    def seek(pos)
      @binlog.seek(pos)
    end

    def unget(char)
      @binlog.ungetc(char)
    end

    def end?
      return false if tail
      @binlog.eof?
    end

    def remaining(header)
      header[:payload_end] - @binlog.tell
    end

    def skip(header)
      seek(header[:next_position])
    end

    def read(length)
      if tail
        needed_position = position + length
        while @binlog.stat.size < needed_position
          sleep 0.02
        end
      end
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
