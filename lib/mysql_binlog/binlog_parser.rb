module MysqlBinlog
  MYSQL_TYPES_HASH = {
    :decimal         => 0,
    :tiny            => 1,
    :short           => 2,
    :long            => 3,
    :float           => 4,
    :double          => 5,
    :null            => 6,
    :timestamp       => 7,
    :longlong        => 8,
    :int24           => 9,
    :date            => 10,
    :time            => 11,
    :datetime        => 12,
    :year            => 13,
    :newdate         => 14,
    :varchar         => 15,
    :bit             => 16,
    :newdecimal      => 246,
    :enum            => 247,
    :set             => 248,
    :tiny_blob       => 249,
    :medium_blob     => 250,
    :long_blob       => 251,
    :blob            => 252,
    :var_string      => 253,
    :string          => 254,
    :geometry        => 255,
  }
  
  MYSQL_TYPES = MYSQL_TYPES_HASH.inject(Array.new(256)) do |type_array, item|
   type_array[item[1]] = item[0]
   type_array
  end

  class BinlogParser
    attr_accessor :binlog
    attr_accessor :reader

    def initialize(binlog_instance)
      @format_cache = {}
      @binlog = binlog_instance
      @reader = binlog_instance.reader
    end

    def read_uint8
      reader.read(1).unpack("C").first
    end

    def read_uint16
      reader.read(2).unpack("v").first
    end

    def read_uint24
      a, b, c = reader.read(3).unpack("CCC")
      a + (b << 8) + (c << 16)
    end

    def read_uint32
      reader.read(4).unpack("V").first
    end

    def read_uint48
      a, b, c = reader.read(6).unpack("vvv")
      a + (b << 16) + (c << 32)
    end

    def read_uint64
      reader.read(8).unpack("Q").first
    end

    def read_float
      reader.read(4).unpack("g").first
    end

    def read_double
      reader.read(8).unpack("G").first
    end

    def read_varint
      # Cheating for now.
      read_uint8
    end

    def read_lpstring
      length = reader.read(1).unpack("C").first
      reader.read(length)
    end

    def read_lpstringz
      string = read_lpstring
      reader.read(1) # null
      string
    end

    def read_nstring(length)
      string = reader.read(length)
      string
    end

    def read_nstringz(length)
      string = reader.read(length)
      reader.read(1) # null
      string
    end

    def read_uint8_array(length)
      reader.read(length).bytes.to_a
    end

    def read_bit_array(length)
      data = reader.read((length+7)/8)
      data.unpack("b*").first.bytes.to_a.map { |i| (i-48) == 1 }.shift(length)
    end

    def read_and_unpack(format_description)
      @format_cache[format_description] ||= {}
      this_format = @format_cache[format_description][:format] ||= 
        format_description.inject("") { |o, f| o+(f[:format] || "") }
      this_length = @format_cache[format_description][:length] ||=
        format_description.inject(0)  { |o, f| o+(f[:length] || 0) }

      fields = {}

      fields_array = reader.read(this_length).unpack(this_format)
      format_description.each_with_index do |field, index| 
        fields[field[:name]] = fields_array[index]
      end

      fields
    end

    def read_mysql_type(column_type)
      case column_type
      #when :decimal
      when :tiny
        read_uint8
      when :short
        read_uint16
      when :int24
        read_uint24
      when :long
        read_uint32
      when :longlong
        read_uint64
      when :string
        length = read_varint
        read_nstring(length)

      when :float
        read_float
      when :double
        read_double
      #when :null
      when :timestamp
        read_uint32
      #when :date
      #when :time
      #when :datetime
      #when :year
      #when :newdate
      #when :varchar
      #when :bit
      #when :newdecimal
      #when :enum
      #when :set
      #when :tiny_blob
      #when :medium_blob
      #when :long_blob
      #when :blob
      #when :var_string
      #when :string
      #when :geometry
      end
    end

  end
end