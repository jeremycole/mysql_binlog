module MysqlBinlog
  class BinlogEventFieldParser
    attr_accessor :binlog

    def initialize(binlog_instance)
      @binlog = binlog_instance
    end

    def unpack_uint48(data)
      a, b, c = data.unpack("vvv")
      a + (b << 16) + (c << 32)
    end

    def read_varint
      binlog.reader.read(1).unpack("C").first
    end

    def read_lpstring
      length = binlog.reader.read(1).unpack("C").first
      binlog.reader.read(length)
    end

    def read_lpstringz
      string = read_lpstring
      binlog.reader.read(1) # null
      string
    end

    def read_uint8_array(length)
      binlog.reader.read(length).bytes.to_a
    end

    def read_bit_array(length)
      data = binlog.reader.read((length+7)/8)
      data.unpack("b*").first.bytes.to_a.map { |i| i-48 }.shift(length)
    end

    def rotate_event(header, fields)
      name_length = binlog.reader.remaining(header)
      fields[:name_length] = name_length
      fields[:name] = binlog.reader.read(name_length)
    end

    def query_event(header, fields)
      # Throw away the status field until we figure out what it's for.
      binlog.reader.read(fields[:status_length])
      fields[:db] = binlog.reader.read(fields[:db_length])
      # Throw away a byte. Don't know what this field is.
      binlog.reader.read(1)
      query_length = binlog.reader.remaining(header)
      fields[:query_length] = query_length
      fields[:query] = binlog.reader.read([query_length, binlog.max_query_length].min)
    end

    def intvar_event(header, fields)
      case fields[:intvar_type]
      when 1
        fields[:intvar_name] = :last_insert_id
      when 2
        fields[:intvar_name] = :insert_id
      else
        fields[:intvar_name] = nil
      end
    end

    def table_map_event(header, fields)
      fields[:table_id] = unpack_uint48(fields[:table_id])
      fields[:db] = read_lpstringz
      fields[:table] = read_lpstringz
      fields[:columns] = read_varint
      fields[:columns_type] = read_uint8_array(fields[:columns])
      fields[:metadata] = read_lpstring
      fields[:columns_nullable] = read_bit_array(fields[:columns])
    end

    def generic_rows_event(header, fields)
      fields[:row_image] = {}
      fields[:table_id] = unpack_uint48(fields[:table_id])
      fields[:columns] = read_varint
      fields[:columns_null] = read_bit_array(fields[:columns])
      if EVENT_TYPES[header[:event_type]] == :update_rows_event
        fields[:columns_update] = read_bit_array(fields[:columns])
      end
    end
    alias :write_rows_event  :generic_rows_event
    alias :update_rows_event :generic_rows_event
    alias :delete_rows_event :generic_rows_event

  end
end