module MysqlBinlog
  # All MySQL types mapping to their integer values.
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

  # All MySQL types in a simple lookup array to map an integer to its symbol.
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

    # Read an unsigned 8-bit (1-byte) integer.
    def read_uint8
      reader.read(1).unpack("C").first
    end

    # Read an unsigned 16-bit (2-byte) integer.
    def read_uint16
      reader.read(2).unpack("v").first
    end

    # Read an unsigned 24-bit (3-byte) integer.
    def read_uint24
      a, b, c = reader.read(3).unpack("CCC")
      a + (b << 8) + (c << 16)
    end

    # Read an unsigned 32-bit (4-byte) integer.
    def read_uint32
      reader.read(4).unpack("V").first
    end

    # Read an unsigned 48-bit (6-byte) integer.
    def read_uint48
      a, b, c = reader.read(6).unpack("vvv")
      a + (b << 16) + (c << 32)
    end

    # Read an unsigned 64-bit (8-byte) integer.
    def read_uint64
      reader.read(8).unpack("Q").first
    end

    # Read a single-precision (4-byte) floating point number.
    def read_float
      reader.read(4).unpack("g").first
    end

    # Read a double-precision (8-byte) floating point number.
    def read_double
      reader.read(8).unpack("G").first
    end

    # Read a variable-length encoded integer. This is very broken at the
    # moment, and is just mapping to read_uint8, so it cannot handle numbers
    # greater than 251. This works fine for most structural elements of binary
    # logs, but will fall over with decoding actual RBR row images.
    def read_varint
      # Cheating for now.
      read_uint8
    end

    # Read a non-terminated string, provided its length.
    def read_nstring(length)
      reader.read(length)
    end

    # Read a null-terminated string, provided its length (without the null).
    def read_nstringz(length)
      string = read_nstring(length)
      reader.read(1) # null
      string
    end

    # Read a (Pascal-style) length-prefixed string. The length is stored as a
    # 8-bit (1-byte) unsigned integer followed by the string itself with no
    # termination character.
    def read_lpstring
      length = read_uint8
      read_nstring(length)
    end

    # Read an lpstring which is also terminated with a null byte.
    def read_lpstringz
      length = read_uint8
      read_nstringz(length)
    end

    # Read an array of unsigned 8-bit (1-byte) integers.
    def read_uint8_array(length)
      reader.read(length).bytes.to_a
    end

    # Read an arbitrary-length bitmap, provided its length. Returns an array
    # of true/false values.
    def read_bit_array(length)
      data = reader.read((length+7)/8)
      data.unpack("b*").first.bytes.to_a.map { |i| (i-48) == 1 }.shift(length)
    end

    def read_uint32_bitmap_by_name(names)
      value = read_uint32
      names.inject([]) do |result, (name, bit_value)|
        if (value & bit_value) != 0
          result << name
        end
        result
      end
    end

    # Read a series of fields, provided an array of field descriptions. This
    # can be used to read many types of fixed-length structures.
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

    # Read a single field, provided the MySQL column type as a symbol. Not all
    # types are currently supported.
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