module MysqlBinlog
  # An array to quickly map an integer event type to its symbol.
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

  # A common fixed-length header that is included with each event.
  EVENT_HEADER = [
    { :name => :timestamp,        :length => 4,   :format => "V"   },
    { :name => :event_type,       :length => 1,   :format => "C"   },
    { :name => :server_id,        :length => 4,   :format => "V"   },
    { :name => :event_length,     :length => 4,   :format => "V"   },
    { :name => :next_position,    :length => 4,   :format => "V"   },
    { :name => :flags,            :length => 2,   :format => "v"   },
  ]

  # Values for the 'flags' field that may appear in binlogs. There are
  # several other values that never appear in a file but may be used
  # in events in memory.
  EVENT_FLAGS = {
    :binlog_in_use   => 0x01,
    :thread_specific => 0x04,
    :suppress_use    => 0x08,
    :artificial      => 0x20,
    :relay_log       => 0x40,
  }

  # Format descriptions for fixed-length fields that may appear in the data
  # for each event. Additional fields may be dynamic and are parsed by the
  # methods in the BinlogEventParser class.
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
  }

  class UnsupportedVersionException < Exception; end
  class MalformedBinlogException < Exception; end
  class ZeroReadException < Exception; end
  class ShortReadException < Exception; end

  class Binlog
    attr_reader :fde
    attr_accessor :reader
    attr_accessor :field_parser
    attr_accessor :event_parser
    attr_accessor :filter_event_types
    attr_accessor :filter_flags
    attr_accessor :max_query_length

    def initialize(reader)
      @reader = reader
      @field_parser = BinlogFieldParser.new(self)
      @event_parser = BinlogEventParser.new(self)
      @fde = nil
      @filter_event_types = nil
      @filter_flags = nil
      @max_query_length = 1048576
    end

    # Rewind to the beginning of the log, if supported by the reader. The
    # reader may throw an exception if rewinding is not supported (e.g. for
    # a stream-based reader).
    def rewind
      reader.rewind
    end

    # Read fixed fields using format definitions in 'unpack' format provided
    # in the EVENT_FORMATS hash.
    def read_fixed_fields(event_type, header)
      if EVENT_FORMATS.include? event_type
        field_parser.read_and_unpack(EVENT_FORMATS[event_type])
      end
    end

    # Read dynamic fields or fields that require more processing before being
    # saved in the event.
    def read_additional_fields(event_type, header, fields)
      if event_parser.methods.include? event_type.to_s
        event_parser.send(event_type, header, fields)
      end
    end

    # Skip the remainder of this event. This can be used to skip an entire
    # event or merely the parts of the event this library does not understand.
    def skip_event(header)
      reader.skip(header)
    end

    # Read the common header for an event. Every event has a header.
    def read_event_header
      header = field_parser.read_and_unpack(EVENT_HEADER)

      # Merge the read 'flags' bitmap with the EVENT_FLAGS hash to return
      # the flags by name instead of returning the bitmap as an integer.
      flags = EVENT_FLAGS.inject([]) do |result, (flag_name, flag_bit_value)|
        if (header[:flags] & flag_bit_value) != 0
          result << flag_name
        end
        result
      end

      # Overwrite the integer version of 'flags' with the array of names.
      header[:flags] = flags

      header
    end

    # Read the content of the event, which consists of an optional fixed field
    # portion and an optional dynamic portion.
    def read_event_content(header)
      event_type = EVENT_TYPES[header[:event_type]]

      # Read the fixed portion of the event, if it is understood, or there is
      # one. If not, initialize content with an empty hash instead.
      content = read_fixed_fields(event_type, header) || {}

      # Read additional fields from the dynamic portion of the event. Some of
      # these may actually be fixed width but needed more processing in a
      # function instead of the unpack formats possible in read_fixed_fields.
      read_additional_fields(event_type, header, content)

      # Anything left unread at this point is skipped based on the event length
      # provided in the header. In this way, it is possible to skip over events
      # that are not able to be parsed correctly by this library.
      skip_event(header)

      content
    end

    # Scan events until finding one that isn't rejected by the filter rules.
    # If there are no filter rules, this will return the next event provided
    # by the reader.
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

        # Never skip over rotate_event or format_description_event as they
        # are critical to understanding the format of this event stream.
        unless [:rotate_event, :format_description_event].include? event_type
          next if skip_this_event
        end
        
        content = read_event_content(header)

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

    # Process a format description event, which describes the version of this
    # file, and the format of events which will appear in this file. This also
    # provides the version of the MySQL server which generated this file.
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

    # Iterate through all events.
    def each_event
      while event = read_event
        yield event
      end
    end
  end
end
