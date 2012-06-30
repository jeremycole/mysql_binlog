module MysqlBinlog
  # A common fixed-length header that is included with each event.
  EVENT_HEADER = [
    { :name => :timestamp,        :length => 4,   :format => "V"   },
    { :name => :event_type,       :length => 1,   :format => "C"   },
    { :name => :server_id,        :length => 4,   :format => "V"   },
    { :name => :event_length,     :length => 4,   :format => "V"   },
    { :name => :next_position,    :length => 4,   :format => "V"   },
    { :name => :flags,            :length => 2,   :format => "v"   },
  ]

  # Values for the +flags+ field that may appear in binary logs. There are
  # several other values that never appear in a file but may be used
  # in events in memory.
  EVENT_HEADER_FLAGS = {
    :binlog_in_use   => 0x01,
    :thread_specific => 0x04,
    :suppress_use    => 0x08,
    :artificial      => 0x20,
    :relay_log       => 0x40,
  }

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

  # A mapping array for all values that may appear in the +status+ field of
  # a query_event.
  QUERY_EVENT_STATUS_TYPES = [
    :flags2,                    # 0
    :sql_mode,                  # 1
    :catalog_deprecated,        # 2
    :auto_increment,            # 3
    :charset,                   # 4
    :time_zone,                 # 5
    :catalog,                   # 6
    :lc_time_names,             # 7
    :charset_database,          # 8
    :table_map_for_update,      # 9
  ]

  # A mapping hash for all values that may appear in the +flags2+ field of
  # a query_event.
  QUERY_EVENT_FLAGS2 = {
    :auto_is_null           => 1 << 14,
    :not_autocommit         => 1 << 19,
    :no_foreign_key_checks  => 1 << 26,
    :relaxed_unique_checks  => 1 << 27,
  }

  # A mapping array for all values that may appear in the +Intvar_type+ field
  # of an intvar_event.
  INTVAR_EVENT_INTVAR_TYPES = [
    nil,
    :last_insert_id,
    :insert_id,
  ]

  # Parse binary log events from a provided binary log. Must be driven
  # externally, but handles all the details of parsing an event header
  # and the content of the various event types.
  class BinlogEventParser
    # The binary log object this event parser will parse events from.
    attr_accessor :binlog

    # The binary log reader extracted from the binlog object for convenience.
    attr_accessor :reader

    # The binary log field parser extracted from the binlog object for
    # convenience.
    attr_accessor :parser

    def initialize(binlog_instance)
      @binlog = binlog_instance
      @reader = binlog_instance.reader
      @parser = binlog_instance.field_parser
      @table_map = {}
    end

    # Parse an event header, described by the +EVENT_HEADER+ structure above.
    def event_header
      header = parser.read_and_unpack(EVENT_HEADER)

      # Merge the read +flags+ bitmap with the +EVENT_HEADER_FLAGS+ hash to
      # return the flags by name instead of returning the bitmap as an integer.
      flags = EVENT_HEADER_FLAGS.inject([]) do |result, (flag_name, flag_bit_value)|
        if (header[:flags] & flag_bit_value) != 0
          result << flag_name
        end
        result
      end

      # Overwrite the integer version of +flags+ with the array of names.
      header[:flags] = flags

      header
    end

    # Parse fields for a +Format_description+ event.
    def format_description_event(header)
      fields = {}
      fields[:binlog_version]   = parser.read_uint16
      fields[:server_version]   = parser.read_nstringz(50)
      fields[:create_timestamp] = parser.read_uint32
      fields[:header_length]    = parser.read_uint8
      fields
    end

    # Parse fields for a +Rotate+ event.
    def rotate_event(header)
      fields = {}
      fields[:pos] = parser.read_uint64
      name_length = reader.remaining(header)
      fields[:name] = parser.read_nstring(name_length)
      fields
    end

    # Parse a dynamic +status+ structure within a query_event, which consists
    # of a status_length (uint16) followed by a number of status variables
    # (determined by the +status_length+) each of which consist of:
    # * A type code (+uint8+), one of +QUERY_EVENT_STATUS_TYPES+.
    # * The content itself, determined by the type. Additional processing is
    #   required based on the type.
    def _query_event_status(header, fields)
      status = {}
      status_length = parser.read_uint16
      end_position = reader.position + status_length
      while reader.position < end_position
        status_type = QUERY_EVENT_STATUS_TYPES[parser.read_uint8]
        status[status_type] = case status_type
        when :flags2
          parser.read_uint32_bitmap_by_name(QUERY_EVENT_FLAGS2)
        when :sql_mode
          parser.read_uint64
        when :catalog_deprecated
          parser.read_lpstringz
        when :auto_increment
          {
            :increment => parser.read_uint16,
            :offset    => parser.read_uint16,
          }
        when :charset
          {
            :character_set_client => COLLATION[parser.read_uint16],
            :collation_connection => COLLATION[parser.read_uint16],
            :collation_server     => COLLATION[parser.read_uint16],
          }
        when :time_zone
          parser.read_lpstring
        when :catalog
          parser.read_lpstring
        when :lc_time_names
          parser.read_uint16
        when :charset_database
          parser.read_uint16
        when :table_map_for_update
          parser.read_uint64
        end
      end
      status
    end
    private :_query_event_status

    # Parse fields for a +Query+ event.
    def query_event(header)
      fields = {}
      fields[:thread_id] = parser.read_uint32
      fields[:elapsed_time] = parser.read_uint32
      db_length = parser.read_uint8
      fields[:error_code] = parser.read_uint16
      fields[:status] = _query_event_status(header, fields)
      fields[:db] = parser.read_nstringz(db_length + 1)
      query_length = reader.remaining(header)
      fields[:query] = reader.read([query_length, binlog.max_query_length].min)
      fields
    end

    # Parse fields for an +Intvar+ event.
    def intvar_event(header)
      fields = {}

      fields[:intvar_type]  = parser.read_uint8
      fields[:intvar_name]  = INTVAR_EVENT_INTVAR_TYPES[fields[:intvar_type]]
      fields[:intvar_value] = parser.read_uint64

      fields
    end

    # Parse fields for an +Xid+ event.
    def xid_event(header)
      fields = {}
      fields[:xid] = parser.read_uint64
      fields
    end

    # Parse fields for an +Rand+ event.
    def rand_event(header)
      fields = {}
      fields[:seed1] = parser.read_uint64
      fields[:seed2] = parser.read_uint64
      fields
    end

    # Parse a number of bytes from the metadata section of a +Table_map+ event
    # representing various fields based on the column type of the column
    # being processed.
    def _table_map_event_column_metadata_read(column_type)
      case column_type
      when :float, :double
        { :size => parser.read_uint8 }
      when :varchar
        { :max_length => parser.read_uint16 }
      when :bit
        {
          :size_bits  => parser.read_uint8,
          :size_bytes => parser.read_uint8,
        }
      when :newdecimal
        {
          :precision => parser.read_uint8,
          :decimals  => parser.read_uint8,
        }
      when :blob, :geometry
        { :length_size => parser.read_uint8 }
      when :string, :var_string
        # The :string type sets a :real_type field to indicate the actual type
        # which is fundamentally incompatible with :string parsing. Setting
        # a :type key in this hash will cause table_map_event to override the
        # main field :type with the provided type here.
        real_type = MYSQL_TYPES[parser.read_uint8]
        case real_type
        when :enum, :set
          { :type => real_type, :size => parser.read_uint8 }
        else
          { :max_length  => parser.read_uint8 }
        end
      end
    end
    private :_table_map_event_column_metadata_read

    # Parse column metadata within a +Table_map+ event.
    def _table_map_event_column_metadata(columns_type)
      length = parser.read_varint
      columns_type.map do |column|
        _table_map_event_column_metadata_read(column)
      end
    end
    private :_table_map_event_column_metadata

    # Parse fields for a +Table_map+ event.
    def table_map_event(header)
      fields = {}
      fields[:table_id] = parser.read_uint48
      fields[:flags] = parser.read_uint16
      map_entry = @table_map[fields[:table_id]] = {}
      map_entry[:db] = parser.read_lpstringz
      map_entry[:table] = parser.read_lpstringz
      columns = parser.read_varint
      columns_type = parser.read_uint8_array(columns).map { |c| MYSQL_TYPES[c] }
      columns_metadata = _table_map_event_column_metadata(columns_type)
      columns_nullable = parser.read_bit_array(columns)

      # Remap overloaded types before we piece together the entire event.
      columns.times do |c|
        if columns_metadata[c] and columns_metadata[c][:type]
          columns_type[c] = columns_metadata[c][:type]
          columns_metadata[c].delete :type
        end
      end

      map_entry[:columns] = columns.times.map do |c|
        {
          :type     => columns_type[c],
          :nullable => columns_nullable[c],
          :metadata => columns_metadata[c],
        }
      end

      fields[:map_entry] = map_entry
      fields
    end

    # Parse a single row image, which is comprised of a series of columns. Not
    # all columns are present in the row image, the columns_used array of true
    # and false values identifies which columns are present.
    def _generic_rows_event_row_image(header, fields, columns_used)
      row_image = []
      columns_null = parser.read_bit_array(fields[:table][:columns].size)
      fields[:table][:columns].each_with_index do |column, column_index|
        if !columns_used[column_index]
          row_image << nil
        elsif columns_null[column_index]
          row_image << { column => nil }
        else
          row_image << {
            column => parser.read_mysql_type(column[:type], column[:metadata])
          }
        end
      end
      row_image
    end
    private :_generic_rows_event_row_image

    # Parse the row images present in a row-based replication row event. This
    # is rather incomplete right now due missing support for many MySQL types,
    # but can parse some basic events.
    def _generic_rows_event_row_images(header, fields, columns_used)
      row_images = []
      end_position = reader.position + reader.remaining(header)
      while reader.position < end_position
        row_image = {}
        case EVENT_TYPES[header[:event_type]]
        when :write_rows_event
          row_image[:after]  = _generic_rows_event_row_image(header, fields, columns_used[:after])
        when :delete_rows_event
          row_image[:before] = _generic_rows_event_row_image(header, fields, columns_used[:before])
        when :update_rows_event
          row_image[:before] = _generic_rows_event_row_image(header, fields, columns_used[:before])
          row_image[:after]  = _generic_rows_event_row_image(header, fields, columns_used[:after])
        end
        row_images << row_image
      end
      row_images
    end
    private :_generic_rows_event_row_images

    # Parse fields for any of the row-based replication row events:
    # * +Write_rows+ which is used for +INSERT+.
    # * +Update_rows+ which is used for +UPDATE+.
    # * +Delete_rows+ which is used for +DELETE+.
    def generic_rows_event(header)
      fields = {}
      table_id = parser.read_uint48
      fields[:table] = @table_map[table_id]
      fields[:flags] = parser.read_uint16
      columns = parser.read_varint
      columns_used = {}
      case EVENT_TYPES[header[:event_type]]
      when :write_rows_event
        columns_used[:after]  = parser.read_bit_array(columns)
      when :delete_rows_event
        columns_used[:before] = parser.read_bit_array(columns)
      when :update_rows_event
        columns_used[:before] = parser.read_bit_array(columns)
        columns_used[:after]  = parser.read_bit_array(columns)
      end
      fields[:row_image] = _generic_rows_event_row_images(header, fields, columns_used)
      fields
    end

    alias :write_rows_event  :generic_rows_event
    alias :update_rows_event :generic_rows_event
    alias :delete_rows_event :generic_rows_event

  end
end