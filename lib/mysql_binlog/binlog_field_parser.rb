require 'bigdecimal'

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
    :timestamp2      => 17,
    :datetime2       => 18,
    :time2           => 19,
    :json            => 245,
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

  # Parse various types of standard and non-standard data types from a
  # provided binary log using its reader to read data.
  class BinlogFieldParser
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

    # Read an unsigned 24-bit (3-byte) big-endian integer.
    def read_uint24_be
      a, b = reader.read(3).unpack("nC")
      (a << 8) + b
    end

    # Read an unsigned 32-bit (4-byte) integer.
    def read_uint32_be
      reader.read(4).unpack("N").first
    end

    # Read an unsigned 32-bit (4-byte) integer.
    def read_uint32
      reader.read(4).unpack("V").first
    end

    # Read an unsigned 40-bit (5-byte) integer.
    def read_uint40
      a, b = reader.read(5).unpack("CV")
      a + (b << 8)
    end

    # Read an unsigned 40-bit (5-byte) big-endian integer.
    def read_uint40_be
      a, b = reader.read(5).unpack("NC")
      (a << 8) + b
    end

    # Read an unsigned 48-bit (6-byte) integer.
    def read_uint48
      a, b, c = reader.read(6).unpack("vvv")
      a + (b << 16) + (c << 32)
    end

    # Read an unsigned 56-bit (7-byte) integer.
    def read_uint56
      a, b, c = reader.read(7).unpack("CvV")
      a + (b << 8) + (c << 24)
    end

    # Read an unsigned 64-bit (8-byte) integer.
    def read_uint64
      reader.read(8).unpack("Q<").first
    end

    # Read an unsigned 64-bit (8-byte) integer.
    def read_uint64_be
      reader.read(8).unpack("Q>").first
    end

    # Read a signed 8-bit (1-byte) integer.
    def read_int8
      reader.read(1).unpack("c").first
    end

    # Read a signed 16-bit (2-byte) big-endian integer.
    def read_int16_be
      reader.read(2).unpack('n').first
    end

    # Read a signed 24-bit (3-byte) big-endian integer.
    def read_int24_be
      a, b, c = reader.read(3).unpack('CCC')
      if (a & 128) == 0
        (a << 16) | (b << 8) | c
      else
        (-1 << 24) | (a << 16) | (b << 8) | c
      end
    end

    # Read a signed 32-bit (4-byte) big-endian integer.
    def read_int32_be
      reader.read(4).unpack('N').first
    end
    
    def read_uint_by_size(size)
      case size
      when 1
        read_uint8
      when 2
        read_uint16
      when 3
        read_uint24
      when 4
        read_uint32
      when 5
        read_uint40
      when 6
        read_uint48
      when 7
        read_uint56
      when 8
        read_uint64
      end
    end

    def read_int_be_by_size(size)
      case size
      when 1
        read_int8
      when 2
        read_int16_be
      when 3
        read_int24_be
      when 4
        read_int32_be
      else
        raise "read_int#{size*8}_be not implemented"
      end
    end

    # Read a single-precision (4-byte) floating point number.
    def read_float
      reader.read(4).unpack("e").first
    end

    # Read a double-precision (8-byte) floating point number.
    def read_double
      reader.read(8).unpack("E").first
    end

    # Read a variable-length "Length Coded Binary" integer. This is derived
    # from the MySQL protocol, and re-used in the binary log format. This
    # format uses the first byte to alternately store the actual value for
    # integer values <= 250, or to encode the number of following bytes
    # used to store the actual value, which can be 2, 3, or 8. It also
    # includes support for SQL NULL as a special case.
    #
    # See: http://forge.mysql.com/wiki/MySQL_Internals_ClientServer_Protocol#Elements
    def read_varint
      first_byte = read_uint8

      case
      when first_byte <= 250
        first_byte
      when first_byte == 251
        nil
      when first_byte == 252
        read_uint16
      when first_byte == 253
        read_uint24
      when first_byte == 254
        read_uint64
      when first_byte == 255
        raise "Invalid variable-length integer"
      end
    end

    # Read a non-terminated string, provided its length.
    def read_nstring(length)
      reader.read(length)
    end

    # Read a null-terminated string, provided its length (with the null).
    def read_nstringz(length)
      reader.read(length).unpack("A*").first
    end

    # Read a (Pascal-style) length-prefixed string. The length is stored as a
    # 8-bit (1-byte) to 32-bit (4-byte) unsigned integer, depending on the
    # optional size parameter (default 1), followed by the string itself with
    # no termination character.
    def read_lpstring(size=1)
      length = read_uint_by_size(size)
      read_nstring(length)
    end

    # Read an lpstring (as above) which is also terminated with a null byte.
    def read_lpstringz(size=1)
      string = read_lpstring(size)
      reader.read(1) # null
      string
    end

    # Read a MySQL-style varint length-prefixed string. The length is stored
    # as a variable-length "Length Coded Binary" value (see read_varint) which
    # is followed by the string content itself. No termination is included.
    def read_varstring
      length = read_varint
      read_nstring(length)
    end

    # Read a (new) decimal value. The value is stored as a sequence of signed
    # big-endian integers, each representing up to 9 digits of the integral
    # and fractional parts. The first integer of the integral part and/or the
    # last integer of the fractional part might be compressed (or packed) and
    # are of variable length. The remaining integers (if any) are
    # uncompressed and 32 bits wide.
    def read_newdecimal(precision, scale)
      digits_per_integer = 9
      compressed_bytes = [0, 1, 1, 2, 2, 3, 3, 4, 4, 4]
      integral = (precision - scale)
      uncomp_integral = integral / digits_per_integer
      uncomp_fractional = scale / digits_per_integer
      comp_integral = integral - (uncomp_integral * digits_per_integer)
      comp_fractional = scale - (uncomp_fractional * digits_per_integer)

      # The sign is encoded in the high bit of the first byte/digit. The byte
      # might be part of a larger integer, so apply the optional bit-flipper
      # and push back the byte into the input stream.
      value = read_uint8
      str, mask = (value & 0x80 != 0) ? ["", 0] : ["-", -1]
      reader.unget(value ^ 0x80)

      size = compressed_bytes[comp_integral]

      if size > 0
        value = read_int_be_by_size(size) ^ mask
        str << value.to_s
      end

      (1..uncomp_integral).each do
        value = read_int32_be ^ mask
        str << value.to_s
      end

      str << "."

      (1..uncomp_fractional).each do
        value = read_int32_be ^ mask
        str << value.to_s
      end

      size = compressed_bytes[comp_fractional]

      if size > 0
        value = read_int_be_by_size(size) ^ mask
        str << value.to_s
      end

      BigDecimal(str)
    end

    # Read an array of unsigned 8-bit (1-byte) integers.
    def read_uint8_array(length)
      reader.read(length).bytes.to_a
    end

    # Read an arbitrary-length bitmap, provided its length. Returns an array
    # of true/false values. This is used both for internal usage in RBR
    # events that need bitmaps, as well as for the BIT type.
    def read_bit_array(length)
      data = reader.read((length+7)/8)
      data.unpack("b*").first.  # Unpack into a string of "10101"
        split("").map { |c| c == "1" }.shift(length) # Return true/false array
    end

    # Read a uint value using the provided size, and convert it to an array
    # of symbols derived from a mapping table provided.
    def read_uint_bitmap_by_size_and_name(size, bit_names)
      value = read_uint_by_size(size)
      named_bits = []

      # Do an efficient scan for the named bits we know about using the hash
      # provided.
      bit_names.each do |(name, bit_value)|
        if (value & bit_value) != 0
          value -= bit_value
          named_bits << name
        end
      end

      # If anything is left over in +value+, add "unknown" names to the result
      # so that they can be identified and corrected.
      if value > 0
        0.upto(size * 8).map { |n| 1 << n }.each do |bit_value|
          if (value & bit_value) != 0
            named_bits << "unknown_#{bit_value}".to_sym
          end
        end
      end

      named_bits
    end

    # Extract a number of sequential bits at a given offset within an integer.
    # This is used to unpack bit-packed fields.
    def extract_bits(value, bits, offset)
      (value & ((1 << bits) - 1) << offset) >> offset
    end

    # Convert a packed +DATE+ from a uint24 into a string representing
    # the date.
    def convert_mysql_type_date(value)
      "%04i-%02i-%02i" % [
        extract_bits(value, 15, 9),
        extract_bits(value,  4, 5),
        extract_bits(value,  5, 0),
      ]
    end

    # Convert a packed +TIME+ from a uint24 into a string representing
    # the time.
    def convert_mysql_type_time(value)
      "%02i:%02i:%02i" % [
        value / 10000,
        (value % 10000) / 100,
        value % 100,
      ]
    end

    # Convert a packed +DATETIME+ from a uint64 into a string representing
    # the date and time.
    def convert_mysql_type_datetime(value)
      date = value / 1000000
      time = value % 1000000

      "%04i-%02i-%02i %02i:%02i:%02i" % [
        date / 10000,
        (date % 10000) / 100,
        date % 100,
        time / 10000,
        (time % 10000) / 100,
        time % 100,
      ]
    end

    def convert_mysql_type_datetimef(int_part, frac_part)
      year_month = extract_bits(int_part, 17, 22)
      year = year_month / 13
      month = year_month % 13
      day = extract_bits(int_part, 5, 17)
      hour = extract_bits(int_part, 5, 12)
      minute = extract_bits(int_part, 6, 6)
      second = extract_bits(int_part, 6, 0)

      "%04i-%02i-%02i %02i:%02i:%02i.%06i" % [
        year,
        month,
        day,
        hour,
        minute,
        second,
        frac_part,
      ]
    end

    def read_datetimef(decimals)
      int_part = read_uint40_be
      frac_part = case decimals
      when 0
        0
      when 1, 2
        read_uint8 * 10000
      when 3, 4
        read_uint16_be * 100
      when 5, 6
        read_uint24_be
      end
      convert_mysql_type_datetimef(int_part, frac_part)
    end

    # Read a single field, provided the MySQL column type as a symbol. Not all
    # types are currently supported.
    def read_mysql_type(type, metadata=nil)
      case type
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
      when :float
        read_float
      when :double
        read_double
      when :var_string
        read_varstring
      when :varchar, :string
        prefix_size = (metadata[:max_length] > 255) ? 2 : 1
        read_lpstring(prefix_size)
      when :blob, :geometry, :json
        read_lpstring(metadata[:length_size])
      when :timestamp
        read_uint32
      when :year
        read_uint8 + 1900
      when :date
        convert_mysql_type_date(read_uint24)
      when :time
        convert_mysql_type_time(read_uint24)
      when :datetime
        convert_mysql_type_datetime(read_uint64)
      when :datetime2
        read_datetimef(metadata[:decimals])
      when :enum, :set
        read_uint_by_size(metadata[:size])
      when :bit
        byte_length = (metadata[:bits]+7)/8
        read_uint_by_size(byte_length)
      when :newdecimal
        precision = metadata[:precision]
        scale = metadata[:decimals]
        read_newdecimal(precision, scale)
      else
        raise UnsupportedTypeException.new("Type #{type} is not supported.")
      end
    end
  end
end
