require 'pp'

module MysqlBinlog

  def pp_hex(data)
    hex = data.bytes.each_slice(24).inject("") do |string, slice|
      string << slice.map { |b| "%02x" % b }.join(" ") + "\n"
      string
    end
    puts hex
  end

  MAGIC = [
    { :name => :magic,            :length => 4,   :format => "V"   },
  ]

  EVENT_HEADER = [
    { :name => :timestamp,        :length => 4,   :format => "V"   },
    { :name => :event_type,       :length => 1,   :format => "C"   },
    { :name => :server_id,        :length => 4,   :format => "V"   },
    { :name => :event_length,     :length => 4,   :format => "V"   },
    { :name => :next_position,    :length => 4,   :format => "V"   },
    { :name => :flags,            :length => 2,   :format => "v"   },
  ]

  EVENT_TYPES = [
    :unknown_event,             #  0
    :start_event_v3,            #  1
    :query_event,               #  2
    :stop_event,                #  3
    :rotate_event,              #  4
    :intvar_event,              #  5
    :load_event,                #  6
    :slave_event,               #  7
    :create_file_event,         #  8
    :append_block_event,        #  9
    :exec_load_event,           # 10
    :delete_file_event,         # 11
    :new_load_event,            # 12
    :rand_event,                # 13
    :user_var_event,            # 14
    :format_description_event,  # 15
    :xid_event,                 # 16
    :begin_load_query_event,    # 17
    :execute_load_query_event,  # 18
    :table_map_event,           # 19
    :pre_ga_write_rows_event,   # 20
    :pre_ga_update_rows_event,  # 21
    :pre_ga_delete_rows_event,  # 22
    :write_rows_event,          # 23
    :update_rows_event,         # 24
    :delete_rows_event,         # 25
    :incident_event,            # 26
    :heartbeat_log_event,       # 27
  ]

  EVENT_FORMATS = {
    :format_description_event => [
      { :name => :binlog_version,   :length => 2,   :format => "v"   },
      { :name => :server_version,   :length => 50,  :format => "A50" },
      { :name => :create_timestamp, :length => 4,   :format => "V"   },
      { :name => :header_length,    :length => 1,   :format => "C"   },
    ],
    :rotate_event => [
      { :name => :pos,              :length => 8,   :format => "Q"   },
    ],
    :query_event => [
      { :name => :thread_id,        :length => 4,   :format => "V"   },
      { :name => :elapsed_time,     :length => 4,   :format => "V"   },
      { :name => :db_length,        :length => 1,   :format => "C"   },
      { :name => :error_code,       :length => 2,   :format => "v"   },
      { :name => :status_length,    :length => 2,   :format => "v"   },
    ],
    :intvar_event => [
      { :name => :intvar_type,      :length => 1,   :format => "C"   },
      { :name => :intvar_value,     :length => 8,   :format => "Q"   },
    ],
    :xid_event => [
      { :name => :xid,              :length => 8,   :format => "Q"   },
    ],
    :rand_event => [ # Untested
      { :name => :seed1,            :length => 8,   :format => "Q"   },
      { :name => :seed2,            :length => 8,   :format => "Q"   },
    ],
    :table_map_event => [
      { :name => :table_id,         :length => 6,   :format => "a6"  },
      { :name => :flags,            :length => 2,   :format => "v"   },
    ],
    :write_rows_event => [
      { :name => :table_id,         :length => 6,   :format => "a6"  },
      { :name => :flags,            :length => 2,   :format => "v"   },
    ],
    :update_rows_event => [
      { :name => :table_id,         :length => 6,   :format => "a6"  },
      { :name => :flags,            :length => 2,   :format => "v"   },
    ],
    :delete_rows_event => [
      { :name => :table_id,         :length => 6,   :format => "a6"  },
      { :name => :flags,            :length => 2,   :format => "v"   },
    ],
    
  }

  class UnsupportedVersionException < Exception; end
  class MalformedBinlogException < Exception; end
  class ZeroReadException < Exception; end
  class ShortReadException < Exception; end

  class Events
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

  class Binlog
    attr_reader :fde
    attr_accessor :reader, :events
    attr_accessor :filter_event_types, :filter_flags
    attr_accessor :max_query_length

    def initialize(reader_class, *args)
      @format_cache = {}

      @reader = reader_class.new(*args)
      @events = Events.new(self)
      @fde = nil
      @filter_event_types = nil
      @filter_flags = nil
      @max_query_length = 1048576
    end

    def rewind
      reader.rewind
      read_file_header
    end

    def read_additional_fields(event_type, header, fields)
      if events.methods.include? event_type.to_s
        events.send(event_type, header, fields)
      end
    end

    def read_and_unpack(format_description)
      @format_cache[format_description] ||= {}
      this_format = @format_cache[format_description][:format] ||= 
        format_description.inject("") { |o, f| o+(f[:format] || "") }
      this_length = @format_cache[format_description][:length] ||=
        format_description.inject(0)  { |o, f| o+(f[:length] || 0) }

      fields = {
        :filename => reader.filename,
        :position => reader.position,
      }

      fields_array = reader.read(this_length).unpack(this_format)
      format_description.each_with_index do |field, index| 
        fields[field[:name]] = fields_array[index]
      end

      fields
    end

    def skip_event(header)
      reader.skip(header)
    end

    def read_event_header
      read_and_unpack(EVENT_HEADER)
    end

    def read_event_content(header)
      content = nil

      event_type = EVENT_TYPES[header[:event_type]]
      if EVENT_FORMATS.include? event_type
        content = read_and_unpack(EVENT_FORMATS[event_type])
      end

      read_additional_fields(event_type, header, content)

      skip_event(header)
      content
    end

    def read_event
      while true
        skip_this_event = false
        return nil if reader.end?

        filename = reader.filename
        position = reader.position

        unless header = read_event_header
          return nil
        end

        event_type = EVENT_TYPES[header[:event_type]]
        
        if @filter_event_types
          unless @filter_event_types.include? event_type or
                  event_type == :format_description_event
            skip_event(header)
            skip_this_event = true
          end
        end
        
        if @filter_flags
          unless @filter_flags.include? header[:flags]
            skip_event(header)
            skip_this_event = true
          end
        end

        unless [:rotate_event, :format_description_event].include? event_type
          next if skip_this_event
        end
        
        content = read_event_content(header)
        content

        case event_type
        when :rotate_event
          reader.rotate(content[:name], content[:pos])
        when :format_description_event
          process_fde(content)
        end

        break
      end

      {
        :type     => event_type,
        :filename => filename,
        :position => position,
        :header   => header,
        :event    => content,
      }
    end

    def process_fde(fde)
      if (version = fde[:binlog_version]) != 4
        raise UnsupportedVersionException.new("Binlog version #{version} is not supported")
      end

      @fde = {
        :header_length  => fde[:header_length],
        :binlog_version => fde[:binlog_version],
        :server_version => fde[:server_version],
      }
    end
  
    def each_event
      while event = read_event
        yield event
      end
    end
  end
  
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
      pp_hex data
      if !data
        #raise MalformedBinlogException.new
      elsif data.length == 0
        raise ZeroReadException.new
      elsif data.length < length
        raise ShortReadException.new
      end
      data
    end
  end
  
  class BinlogEventStreamReader
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
