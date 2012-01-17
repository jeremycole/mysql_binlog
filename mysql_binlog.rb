require 'pp'

module MysqlBinlog

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
  }

  class UnsupportedVersionException < Exception; end
  class MalformedBinlogException < Exception; end
  class ZeroReadException < Exception; end
  class ShortReadException < Exception; end

  class Binlog
    attr_reader :fde
    attr_accessor :filter_event_types, :filter_flags
    attr_accessor :max_query_length

    def initialize(filename)
      @format_cache = {}

      @filename = filename
      @binlog = File.open(filename, mode="r")
      @fde = nil
      @filter_event_types = nil
      @filter_flags = nil
      @max_query_length = 1048576

      read_file_header
    end

    def rewind
      @binlog.rewind
      read_file_header
      tell
    end

    def seek(pos)
      @binlog.seek(pos)
    end

    def tell
      @binlog.tell
    end
    
    def eof?
      @binlog.eof?
    end

    def read(length)
      return "" if length == 0
      data = @binlog.read(length)
      if data.length == 0
        raise ZeroReadException.new
      elsif data.length < length
        raise ShortReadException.new
      end
      data
    end

    def read_additional_fields(event_type, header, fields)
      case event_type
      when :query_event
        # Throw away the status field until we figure out what it's for.
        read(fields[:status_length])
        fields[:db] = read(fields[:db_length])
        # Throw away a byte. Don't know what this field is.
        read(1)
        query_length = header[:next_position] - tell
        fields[:query_length] = query_length
        fields[:query] = read([query_length, @max_query_length].min)
      when :intvar_event
        case fields[:intvar_type]
        when 1
          fields[:intvar_name] = :last_insert_id
        when 2
          fields[:intvar_name] = :insert_id
        else
          fields[:intvar_name] = nil
        end
      end
      nil
      #fields
    end

    def read_and_unpack(format_description)
      @format_cache[format_description] ||= {}
      this_format = @format_cache[format_description][:format] ||= 
        format_description.inject("") { |o, f| o+(f[:format] || "") }
      this_length = @format_cache[format_description][:length] ||=
        format_description.inject(0)  { |o, f| o+(f[:length] || 0) }

      fields = {
        :position => tell
      }

      fields_array = read(this_length).unpack(this_format)
      format_description.each_with_index do |field, index| 
        fields[field[:name]] = fields_array[index]
      end

      fields
    end

    def read_magic
      magic = read_and_unpack(MAGIC)
      magic[:magic]
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

      seek header[:next_position]
      content
    end

    def read_event
      while true
        return nil if eof?

        unless header = read_event_header
          return nil
        end
      
        if @filter_event_types
          unless @filter_event_types.include? EVENT_TYPES[header[:event_type]]
            seek header[:next_position]
            next
          end
        end
        
        if @filter_flags
          unless @filter_flags.include? header[:flags]
            seek header[:next_position]
            next
          end
        end
        
        break
      end          

      {
        :type     => EVENT_TYPES[header[:event_type]],
        :position => header[:position],
        :header   => header,
        :event    => read_event_content(header),
      }
    end

    def read_file_header
      if (magic = read_magic) != 1852400382
        raise MalformedBinlogException.new("Magic number #{magic} is incorrect")
      end

      fde = read_event

      if EVENT_TYPES[fde[:header][:event_type]] != :format_description_event
        raise MalformedBinlogException.new("Missing format description event at start of binary log")
      end

      if (version = fde[:event][:binlog_version]) != 4
        raise UnsupportedVersionException.new("Binlog version #{version} is not supported")
      end

      @fde = {
        :header_length  => fde[:event][:header_length],
        :binlog_version => fde[:event][:binlog_version],
        :server_version => fde[:event][:server_version],
      }
    end
  
    def each_event
      while event = read_event
        yield event
      end
    end
  end
end
