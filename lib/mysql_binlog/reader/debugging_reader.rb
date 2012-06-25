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
    def initialize(wrapped, options={})
      @wrapped = wrapped
      @options = options
    end

    # Pass through all method calls.
    def method_missing(method, *args)
      if @options[:calls]
        puts "#{@wrapped.class}.#{method}"
      end

      return_value = @wrapped.send(method, *args)

      # Print the returned data from :read in a nice hex dump format.
      if method == :read and @options[:data]
        puts "Read #{args[0]} bytes #{caller.first.split(":")[2]}:"
        puts hexdump(return_value)
      end

      return_value
    end
  end
end