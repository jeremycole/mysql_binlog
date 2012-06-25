module MysqlBinlog
  # A simple method to print a string as in hex representation per byte,
  # with no more than 24 bytes per line, and spaces between each byte.
  # There is probably a better way to do this, but I don't know it.
  def hexdump(data)
    data.bytes.each_slice(24).inject("") do |string, slice|
      string << "  " + slice.map { |b| "%02x" % b }.join(" ") + "\n"
      string
    end
  end

  
  class DebuggingReader
    def initialize(wrapped)
      @wrapped = wrapped
    end

    # Print the function name of the calling function, followed by the data
    # read in a nice hex format.
    def read(length)
      data = @wrapped.read(length)
      puts "Read #{length} bytes #{caller.first.split(":")[2]}:"
      puts hexdump(data)

      data
    end

    # Pass through all other method calls.
    def method_missing(method, *args)
      @wrapped.send(method, *args)
    end
  end
end