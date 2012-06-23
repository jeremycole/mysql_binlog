module MysqlBinlog
  QUERY_EVENT_STATUS_TYPES = [
    :flags2,
    :sql_mode,
    :catalog,
    :auto_increment,
    :charset,
    :time_zone,
    :catalog_nz,
    :lc_time_names,
    :charset_database,
    :table_map_for_update,
  ]

  QUERY_EVENT_FLAGS2 = {
    :auto_is_null           => 1 << 14,
    :not_autocommit         => 1 << 19,
    :no_foreign_key_checks  => 1 << 26,
    :relaxed_unique_checks  => 1 << 27,
  }

  class BinlogEventFieldParser
    attr_accessor :binlog
    attr_accessor :reader
    attr_accessor :parser

    def initialize(binlog_instance)
      @binlog = binlog_instance
      @reader = binlog_instance.reader
      @parser = binlog_instance.parser
      @table_map = {}
    end

    def rotate_event(header, fields)
      name_length = reader.remaining(header)
      fields[:name_length] = name_length
      fields[:name] = reader.read(name_length)
    end

    def _query_event_status(header, fields)
      status = {}
      end_position = reader.position + fields[:status_length]
      while reader.position < end_position
        status_type = QUERY_EVENT_STATUS_TYPES[parser.read_uint8]
        status[status_type] = case status_type
        when :flags2
          flags2 = parser.read_uint32
          QUERY_EVENT_FLAGS2.inject([]) do |result, (flag_name, flag_bit_value)|
            if (flags2 & flag_bit_value) != 0
              result << flag_name
            end
            result
          end
        when :sql_mode
          parser.read_uint64
        when :catalog
          parser.read_lpstringz
        when :auto_increment
          {
            :increment => parser.read_uint16,
            :offset    => parser.read_uint16,
          }
        when :charset
          {
            :character_set_client => parser.read_uint16,
            :collation_connection => parser.read_uint16,
            :collation_server     => parser.read_uint16,
          }
        when :time_zone
          parser.read_lpstring
        when :catalog_nz
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

    def query_event(header, fields)
      fields[:status] = _query_event_status(header, fields)
      fields.delete :status_length
      fields[:db] = parser.read_nstringz(fields[:db_length])
      fields.delete :db_length
      query_length = reader.remaining(header)
      fields[:query] = reader.read([query_length, binlog.max_query_length].min)
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
      fields[:table_id] = parser.read_uint48
      fields[:flags] = parser.read_uint16
      map_entry = @table_map[fields[:table_id]] = {}
      map_entry[:db] = parser.read_lpstringz
      map_entry[:table] = parser.read_lpstringz
      columns = parser.read_varint
      columns_type = parser.read_uint8_array(columns).map { |c| MYSQL_TYPES[c] }
      columns_metadata = parser.read_lpstring
      columns_nullable = parser.read_bit_array(columns)

      map_entry[:columns] = columns.times.map do |c|
        {
          :type     => columns_type[c],
          :nullable => columns_nullable[c],
        }
      end

      fields[:map_entry] = map_entry
    end

    def _generic_rows_event_row_images(header, fields)
      row_images = []
      end_position = reader.position + reader.remaining(header)
      while reader.position < end_position
        row_image = []
        columns_null = parser.read_bit_array(fields[:table][:columns].size)
        fields[:table][:columns].each_with_index do |column, column_index|
          if !fields[:columns_used][column_index]
            row_image << nil
          elsif columns_null[column_index]
            row_image << { column => nil }
          else
            row_image << { column => parser.read_mysql_type(column[:type]) }
          end
        end
        row_images << row_image
      end
      row_images
    end

    def generic_rows_event(header, fields)
      table_id = parser.read_uint48
      fields[:table] = @table_map[table_id]
      fields[:flags] = parser.read_uint16
      columns = parser.read_varint
      fields[:columns_used] = parser.read_bit_array(columns)
      if EVENT_TYPES[header[:event_type]] == :update_rows_event
        fields[:columns_update] = parser.read_bit_array(columns)
      end
      fields[:row_image] = _generic_rows_event_row_images(header, fields)
      fields.delete :columns_used
    end
    alias :write_rows_event  :generic_rows_event
    alias :update_rows_event :generic_rows_event
    alias :delete_rows_event :generic_rows_event

  end
end