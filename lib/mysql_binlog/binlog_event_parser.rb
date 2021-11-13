module MysqlBinlog
  # A hash of all possible event type IDs.
  #
  # Enumerated in sql/log_event.h line ~539 as Log_event_type
  EVENT_TYPES_HASH = {
    :unknown_event              =>  0,  #
    :start_event_v3             =>  1,  # (deprecated)
    :query_event                =>  2,  #
    :stop_event                 =>  3,  #
    :rotate_event               =>  4,  #
    :intvar_event               =>  5,  #
    :load_event                 =>  6,  # (deprecated)
    :slave_event                =>  7,  # (deprecated)
    :create_file_event          =>  8,  # (deprecated)
    :append_block_event         =>  9,  #
    :exec_load_event            => 10,  # (deprecated)
    :delete_file_event          => 11,  #
    :new_load_event             => 12,  # (deprecated)
    :rand_event                 => 13,  #
    :user_var_event             => 14,  #
    :format_description_event   => 15,  #
    :xid_event                  => 16,  #
    :begin_load_query_event     => 17,  #
    :execute_load_query_event   => 18,  #
    :table_map_event            => 19,  #
    :pre_ga_write_rows_event    => 20,  # (deprecated)
    :pre_ga_update_rows_event   => 21,  # (deprecated)
    :pre_ga_delete_rows_event   => 22,  # (deprecated)
    :write_rows_event_v1        => 23,  #
    :update_rows_event_v1       => 24,  #
    :delete_rows_event_v1       => 25,  #
    :incident_event             => 26,  #
    :heartbeat_log_event        => 27,  #
    :ignorable_log_event        => 28,  #
    :rows_query_log_event       => 29,  #
    :write_rows_event_v2        => 30,  #
    :update_rows_event_v2       => 31,  #
    :delete_rows_event_v2       => 32,  #
    :gtid_log_event             => 33,  #
    :anonymous_gtid_log_event   => 34,  #
    :previous_gtids_log_event   => 35,  #
    :transaction_context_event  => 36,  #
    :view_change_event          => 37,  #
    :xa_prepare_log_event       => 38,  #

    :table_metadata_event       => 50,  # Only in Twitter MySQL
  }

  # A lookup array to map an integer event type ID to its symbol.
  EVENT_TYPES = EVENT_TYPES_HASH.inject(Array.new(256)) do |type_array, item|
   type_array[item[1]] = item[0]
   type_array
  end

  # A list of supported row-based replication event types. Since these all
  # have an identical structure, this list can be used by other programs to
  # know which events can be treated as row events.
  ROW_EVENT_TYPES = [
    :write_rows_event_v1,
    :update_rows_event_v1,
    :delete_rows_event_v1,
    :write_rows_event_v2,
    :update_rows_event_v2,
    :delete_rows_event_v2,
  ]

  # Values for the +flags+ field that may appear in binary logs. There are
  # several other values that never appear in a file but may be used
  # in events in memory.
  #
  # Defined in sql/log_event.h line ~448
  EVENT_HEADER_FLAGS = {
    :binlog_in_use    => 0x0001, # LOG_EVENT_BINLOG_IN_USE_F
    :thread_specific  => 0x0004, # LOG_EVENT_THREAD_SPECIFIC_F
    :suppress_use     => 0x0008, # LOG_EVENT_SUPPRESS_USE_F
    :artificial       => 0x0020, # LOG_EVENT_ARTIFICIAL_F
    :relay_log        => 0x0040, # LOG_EVENT_RELAY_LOG_F
    :ignorable        => 0x0080, # LOG_EVENT_IGNORABLE_F
    :no_filter        => 0x0100, # LOG_EVENT_NO_FILTER_F
    :mts_isolate      => 0x0200, # LOG_EVENT_MTS_ISOLATE_F
  }

  # A mapping array for all values that may appear in the +status+ field of
  # a query_event.
  #
  # Defined in sql/log_event.h line ~316
  QUERY_EVENT_STATUS_TYPES = [
    :flags2,                    #  0 (Q_FLAGS2_CODE)
    :sql_mode,                  #  1 (Q_SQL_MODE_CODE)
    :catalog_deprecated,        #  2 (Q_CATALOG_CODE)
    :auto_increment,            #  3 (Q_AUTO_INCREMENT)
    :charset,                   #  4 (Q_CHARSET_CODE)
    :time_zone,                 #  5 (Q_TIME_ZONE_CODE)
    :catalog,                   #  6 (Q_CATALOG_NZ_CODE)
    :lc_time_names,             #  7 (Q_LC_TIME_NAMES_CODE)
    :charset_database,          #  8 (Q_CHARSET_DATABASE_CODE)
    :table_map_for_update,      #  9 (Q_TABLE_MAP_FOR_UPDATE_CODE)
    :master_data_written,       # 10 (Q_MASTER_DATA_WRITTEN_CODE)
    :invoker,                   # 11 (Q_INVOKER)
    :updated_db_names,          # 12 (Q_UPDATED_DB_NAMES)
    :microseconds,              # 13 (Q_MICROSECONDS)
    :commit_ts,                 # 14 (Q_COMMIT_TS)
    :commit_ts2,                # 15
    :explicit_defaults_for_timestamp, # 16 (Q_EXPLICIT_DEFAULTS_FOR_TIMESTAMP)
  ]

  QUERY_EVENT_OVER_MAX_DBS_IN_EVENT_MTS = 254

  # A mapping hash for all values that may appear in the +flags2+ field of
  # a query_event.
  #
  # Defined in sql/log_event.h line ~521 in OPTIONS_WRITTEN_TO_BIN_LOG
  #
  # Defined in sql/sql_priv.h line ~84
  QUERY_EVENT_FLAGS2 = {
    :auto_is_null           => 1 << 14, # OPTION_AUTO_IS_NULL
    :not_autocommit         => 1 << 19, # OPTION_NOT_AUTOCOMMIT
    :no_foreign_key_checks  => 1 << 26, # OPTION_NO_FOREIGN_KEY_CHECKS
    :relaxed_unique_checks  => 1 << 27, # OPTION_RELAXED_UNIQUE_CHECKS
  }

  # A mapping array for all values that may appear in the +Intvar_type+ field
  # of an intvar_event.
  #
  # Enumerated in sql/log_event.h line ~613 as Int_event_type
  INTVAR_EVENT_INTVAR_TYPES = [
    nil,                # INVALID_INT_EVENT
    :last_insert_id,    # LAST_INSERT_ID_EVENT
    :insert_id,         # INSERT_ID_EVENT
  ]

  # A mapping array for all values that may appear in the +flags+ field of a
  # table_map_event.
  #
  # Enumerated in sql/log_event.h line ~3413 within Table_map_log_event
  TABLE_MAP_EVENT_FLAGS = {
    :bit_len_exact          => 1 << 0,  # TM_BIT_LEN_EXACT_F
  }

  # A mapping array for all values that may appear in the +flags+ field of a
  # table_metadata_event.
  #
  # There are none of these at the moment.
  TABLE_METADATA_EVENT_FLAGS = {
  }

  # A mapping hash for all values that may appear in the +flags+ field of
  # a column descriptor for a table_metadata_event.
  #
  # Defined in include/mysql_com.h line ~92
  TABLE_METADATA_EVENT_COLUMN_FLAGS = {
    :not_null             =>     1, # NOT_NULL_FLAG
    :primary_key          =>     2, # PRI_KEY_FLAG
    :unique_key           =>     4, # UNIQUE_KEY_FLAG
    :multiple_key         =>     8, # MULTIPLE_KEY_FLAG
    :blob                 =>    16, # BLOB_FLAG
    :unsigned             =>    32, # UNSIGNED_FLAG
    :zerofill             =>    64, # ZEROFILL_FLAG
    :binary               =>   128, # BINARY_FLAG
    :enum                 =>   256, # ENUM_FLAG
    :auto_increment       =>   512, # AUTO_INCREMENT_FLAG
    :timestamp            =>  1024, # TIMESTAMP_FLAG
    :set                  =>  2048, # SET_FLAG
    :no_default_value     =>  4096, # NO_DEFAULT_VALUE_FLAG
    :on_update_now        =>  8192, # ON_UPDATE_NOW_FLAG
    :part_key             => 16384, # PART_KEY_FLAG
  }

  # A mapping array for all values that may appear in the +flags+ field of a
  # write_rows_event, update_rows_event, or delete_rows_event.
  #
  # Enumerated in sql/log_event.h line ~3533 within Rows_log_event
  GENERIC_ROWS_EVENT_FLAGS = {
    :stmt_end               => 1 << 0,  # STMT_END_F
    :no_foreign_key_checks  => 1 << 1,  # NO_FOREIGN_KEY_CHECKS_F
    :relaxed_unique_checks  => 1 << 2,  # RELAXED_UNIQUE_CHECKS_F
    :complete_rows          => 1 << 3,  # COMPLETE_ROWS_F
  }

  GENERIC_ROWS_EVENT_VH_FIELD_TYPES = [
    :extra_rows_info,                   # ROWS_V_EXTRAINFO_TAG
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

    # Parse an event header, which is consistent for all event types.
    #
    # Documented in sql/log_event.h line ~749 as "Common-Header"
    #
    # Implemented in sql/log_event.cc line ~936 in Log_event::write_header
    def event_header
      header = {}
      header[:timestamp]      = parser.read_uint32
      event_type = parser.read_uint8
      header[:event_type]     = EVENT_TYPES[event_type] || "unknown_#{event_type}".to_sym
      header[:server_id]      = parser.read_uint32
      header[:event_length]   = parser.read_uint32
      header[:next_position]  = parser.read_uint32
      header[:flags] = parser.read_uint_bitmap_by_size_and_name(2, EVENT_HEADER_FLAGS)

      header
    end

    # Parse fields for a +Format_description+ event.
    #
    # Implemented in sql/log_event.cc line ~4123 in Format_description_log_event::write
    def format_description_event(header)
      fields = {}
      fields[:binlog_version]   = parser.read_uint16
      fields[:server_version]   = parser.read_nstringz(50)
      fields[:create_timestamp] = parser.read_uint32
      fields[:header_length]    = parser.read_uint8
      fields
    end

    # Parse fields for a +Rotate+ event.
    #
    # Implemented in sql/log_event.cc line ~5157 in Rotate_log_event::write
    def rotate_event(header)
      fields = {}
      fields[:pos] = parser.read_uint64
      name_length = reader.remaining(header)
      fields[:name] = parser.read_nstring(name_length)
      fields
    end

    def _query_event_status_updated_db_names
      db_count = parser.read_uint8
      return nil if db_count == QUERY_EVENT_OVER_MAX_DBS_IN_EVENT_MTS

      db_names = []
      db_count.times do |n|
        db_name = ""
        loop do
          c = reader.read(1)
          break if c == "\0"
          db_name << c
        end
        db_names << db_name
      end

      db_names
    end
    private :_query_event_status_updated_db_names

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
        status_type_id = parser.read_uint8
        status_type = QUERY_EVENT_STATUS_TYPES[status_type_id]
        status[status_type] = case status_type
        when :flags2
          parser.read_uint_bitmap_by_size_and_name(4, QUERY_EVENT_FLAGS2)
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
        when :master_data_written
          parser.read_uint32
        when :invoker
          {
            :user => parser.read_lpstring,
            :host => parser.read_lpstring,
          }
        when :updated_db_names
          _query_event_status_updated_db_names
        when :commit_ts
          parser.read_uint64
        when :microseconds
          parser.read_uint24
        when :explicit_defaults_for_timestamp
          parser.read_uint8
        else
          raise "Unknown status type #{status_type_id}"
        end
      end

      # We may have read too much due to an invalid string read especially.
      # Raise a more specific exception here instead of the generic
      # OverReadException from the entire event.
      if reader.position > end_position
        raise OverReadException.new("Read past end of Query event status field")
      end

      status
    end
    private :_query_event_status

    # Parse fields for a +Query+ event.
    #
    # Implemented in sql/log_event.cc line ~2214 in Query_log_event::write
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
    #
    # Implemented in sql/log_event.cc line ~5326 in Intvar_log_event::write
    def intvar_event(header)
      fields = {}

      fields[:intvar_type]  = parser.read_uint8
      fields[:intvar_name]  = INTVAR_EVENT_INTVAR_TYPES[fields[:intvar_type]]
      fields[:intvar_value] = parser.read_uint64

      fields
    end

    # Parse fields for an +Xid+ event.
    #
    # Implemented in sql/log_event.cc line ~5559 in Xid_log_event::write
    def xid_event(header)
      fields = {}
      fields[:xid] = parser.read_uint64
      fields
    end

    # Parse fields for an +Rand+ event.
    #
    # Implemented in sql/log_event.cc line ~5454 in Rand_log_event::write
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
        bits  = parser.read_uint8
        bytes = parser.read_uint8
        {
          :bits  => (bytes * 8) + bits
        }
      when :newdecimal
        {
          :precision => parser.read_uint8,
          :decimals  => parser.read_uint8,
        }
      when :blob, :geometry, :json
        { :length_size => parser.read_uint8 }
      when :string, :var_string
        # The :string type sets a :real_type field to indicate the actual type
        # which is fundamentally incompatible with :string parsing. Setting
        # a :type key in this hash will cause table_map_event to override the
        # main field :type with the provided type here.
        # See Field_string::do_save_field_metadata for reference.
        metadata  = (parser.read_uint8 << 8) + parser.read_uint8
        real_type = MYSQL_TYPES[metadata >> 8]
        case real_type
        when :enum, :set
          { :type => real_type, :size => metadata & 0x00ff }
        else
          { :max_length  => (((metadata >> 4) & 0x300) ^ 0x300) + (metadata & 0x00ff) }
        end
      when :timestamp2, :datetime2, :time2
        {
          :decimals => parser.read_uint8,
        }
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
    #
    # Implemented in sql/log_event.cc line ~8638
    # in Table_map_log_event::write_data_header
    # and Table_map_log_event::write_data_body
    def table_map_event(header)
      fields = {}
      fields[:table_id] = parser.read_uint48
      fields[:flags] = parser.read_uint_bitmap_by_size_and_name(2, TABLE_MAP_EVENT_FLAGS)
      map_entry = @table_map[fields[:table_id]] = {}
      map_entry[:db] = parser.read_lpstringz
      map_entry[:table] = parser.read_lpstringz
      columns = parser.read_varint
      columns_type = parser.read_uint8_array(columns).map { |c| MYSQL_TYPES[c] || "unknown_#{c}".to_sym }
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

    # Parse fields for a +Table_metadata+ event, which is specific to
    # Twitter MySQL releases at the moment.
    #
    # Implemented in sql/log_event.cc line ~8772 (in Twitter MySQL)
    # in Table_metadata_log_event::write_data_header
    # and Table_metadata_log_event::write_data_body
    def table_metadata_event(header)
      fields = {}
      table_id = parser.read_uint48
      columns = parser.read_uint16

      fields[:table] = @table_map[table_id]
      fields[:flags] = parser.read_uint16
      fields[:columns] = columns.times.map do |c|
        descriptor_length = parser.read_uint32
        column_type = parser.read_uint8
        @table_map[table_id][:columns][c][:description] = {
          :type => MYSQL_TYPES[column_type] || "unknown_#{column_type}".to_sym,
          :length => parser.read_uint32,
          :scale => parser.read_uint8,
          :character_set => COLLATION[parser.read_uint16],
          :flags => parser.read_uint_bitmap_by_size_and_name(2,
                    TABLE_METADATA_EVENT_COLUMN_FLAGS),
          :name => parser.read_varstring,
          :type_name => parser.read_varstring,
          :comment => parser.read_varstring,
        }
      end
      fields
    end

    # Parse a single row image, which is comprised of a series of columns. Not
    # all columns are present in the row image, the columns_used array of true
    # and false values identifies which columns are present.
    def _generic_rows_event_row_image(header, fields, columns_used)
      row_image = []
      start_position = reader.position
      columns_null = parser.read_bit_array(fields[:table][:columns].size)
      fields[:table][:columns].each_with_index do |column, column_index|
        #puts "column #{column_index} #{column}: used=#{columns_used[column_index]}, null=#{columns_null[column_index]}"
        if !columns_used[column_index]
          row_image << nil
        elsif columns_null[column_index]
          row_image << { column_index => nil }
        else
          value = parser.read_mysql_type(column[:type], column[:metadata])
          row_image << {
            column_index => value,
          }
        end
      end
      end_position = reader.position

      {
        image: row_image,
        size: end_position-start_position
      }
    end
    private :_generic_rows_event_row_image

    def diff_row_images(before, after)
      diff = {}
      before.each_with_index do |before_column, index|
        after_column = after[index]
        before_value = before_column.first[1]
        after_value = after_column.first[1]
        if before_value != after_value
          diff[index] = { before: before_value, after: after_value }
        end
      end
      diff
    end

    # Parse the row images present in a row-based replication row event. This
    # is rather incomplete right now due missing support for many MySQL types,
    # but can parse some basic events.
    def _generic_rows_event_row_images(header, fields, columns_used)
      row_images = []
      end_position = reader.position + reader.remaining(header)
      while reader.position < end_position
        row_image = {}
        case header[:event_type]
        when :write_rows_event_v1, :write_rows_event_v2
          row_image[:after]  = _generic_rows_event_row_image(header, fields, columns_used[:after])
        when :delete_rows_event_v1, :delete_rows_event_v2
          row_image[:before] = _generic_rows_event_row_image(header, fields, columns_used[:before])
        when :update_rows_event_v1, :update_rows_event_v2
          row_image[:before] = _generic_rows_event_row_image(header, fields, columns_used[:before])
          row_image[:after]  = _generic_rows_event_row_image(header, fields, columns_used[:after])
          row_image[:diff] = diff_row_images(row_image[:before][:image], row_image[:after][:image])
        end
        row_images << row_image
      end

      # We may have read too much, especially if any of the fields in the row
      # image were misunderstood. Raise a more specific exception here instead
      # of the generic OverReadException from the entire event.
      if reader.position > end_position
        raise OverReadException.new("Read past end of row image")
      end

      row_images
    end
    private :_generic_rows_event_row_images

    # Parse the variable header from a v2 rows event. This is only used for
    # ROWS_V_EXTRAINFO_TAG which is used by NDB. Ensure it can be skipped
    # properly but don't bother parsing it.
    def _generic_rows_event_vh
      vh_payload_len = parser.read_uint16 - 2
      return unless vh_payload_len > 0

      reader.read(vh_payload_len)
    end

    # Parse fields for any of the row-based replication row events:
    # * +Write_rows+ which is used for +INSERT+.
    # * +Update_rows+ which is used for +UPDATE+.
    # * +Delete_rows+ which is used for +DELETE+.
    #
    # Implemented in sql/log_event.cc line ~8039
    # in Rows_log_event::write_data_header
    # and Rows_log_event::write_data_body
    def _generic_rows_event(header, contains_vh: false)
      fields = {}
      table_id = parser.read_uint48
      fields[:table] = @table_map[table_id]
      fields[:flags] = parser.read_uint_bitmap_by_size_and_name(2, GENERIC_ROWS_EVENT_FLAGS)

      # Rows_log_event v2 events contain a variable-sized header. Only NDB
      # uses it right now, so let's just make sure it's skipped properly.
      _generic_rows_event_vh if contains_vh

      columns = parser.read_varint
      columns_used = {}
      case header[:event_type]
      when :write_rows_event_v1, :write_rows_event_v2
        columns_used[:after]  = parser.read_bit_array(columns)
      when :delete_rows_event_v1, :delete_rows_event_v2
        columns_used[:before] = parser.read_bit_array(columns)
      when :update_rows_event_v1, :update_rows_event_v2
        columns_used[:before] = parser.read_bit_array(columns)
        columns_used[:after]  = parser.read_bit_array(columns)
      end
      fields[:row_image] = _generic_rows_event_row_images(header, fields, columns_used)
      fields
    end
    private :_generic_rows_event

    def generic_rows_event_v1(header)
      _generic_rows_event(header, contains_vh: false)
    end

    alias :write_rows_event_v1  :generic_rows_event_v1
    alias :update_rows_event_v1 :generic_rows_event_v1
    alias :delete_rows_event_v1 :generic_rows_event_v1

    def generic_rows_event_v2(header)
      _generic_rows_event(header, contains_vh: true)
    end

    alias :write_rows_event_v2  :generic_rows_event_v2
    alias :update_rows_event_v2 :generic_rows_event_v2
    alias :delete_rows_event_v2 :generic_rows_event_v2

    def rows_query_log_event(header)
      reader.read(1) # skip useless byte length which is unused
      { query: reader.read(header[:payload_length]-1) }
    end

    def in_hex(bytes)
      bytes.each_byte.map { |c| "%02x" % c.ord }.join
    end

    def format_gtid_sid(sid)
      [0..3, 4..5, 6..7, 8..9, 10..15].map { |r| in_hex(sid[r]) }.join("-")
    end

    # 6d9190a2-cca6-11e8-aa8c-42010aef0019:551845019
    def format_gtid(sid, gno_or_ivs)
      "#{format_gtid_sid(sid)}:#{gno_or_ivs}"
    end

    def previous_gtids_log_event(header)
      n_sids = parser.read_uint64

      gtids = []
      n_sids.times do
        sid = parser.read_nstring(16)
        n_ivs = parser.read_uint64
        ivs = []
        n_ivs.times do
          iv_start = parser.read_uint64
          iv_end = parser.read_uint64
          ivs << "#{iv_start}-#{iv_end}"
        end
        gtids << format_gtid(sid, ivs.join(":"))
      end

      {
        previous_gtids: gtids
      }
    end

    def gtid_log_event(header)
      flags = parser.read_uint8
      sid = parser.read_nstring(16)
      gno = parser.read_uint64
      lts_type = parser.read_uint8
      lts_last_committed = parser.read_uint64
      lts_sequence_number = parser.read_uint64

      {
        flags: flags,
        gtid: format_gtid(sid, gno),
        lts: {
          type: lts_type,
          last_committed: lts_last_committed,
          sequence_number: lts_sequence_number,
        },
      }
    end
  end
end
