module MysqlBinlog
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

    # Skip the remainder of this event. This can be used to skip an entire
    # event or merely the parts of the event this library does not understand.
    def skip_event(header)
      reader.skip(header)
    end

    # Read the content of the event, which follows the header.
    def read_event_fields(header)
      event_type = EVENT_TYPES[header[:event_type]]

      # Delegate the parsing of the event content to a method of the same name
      # in BinlogEventParser.
      if event_parser.methods.include? event_type.to_s
        fields = event_parser.send(event_type, header)
      end

      # Anything left unread at this point is skipped based on the event length
      # provided in the header. In this way, it is possible to skip over events
      # that are not able to be parsed correctly by this library.
      skip_event(header)

      fields
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

        # Read the common header for an event. Every event has a header.
        unless header = event_parser.event_header
          return nil
        end

        event_type = EVENT_TYPES[header[:event_type]]
        
        if @filter_event_types
          unless @filter_event_types.include? event_type
            skip_this_event = true
          end
        end
        
        if @filter_flags
          unless @filter_flags.include? header[:flags]
            skip_this_event = true
          end
        end

        # Never skip over rotate_event or format_description_event as they
        # are critical to understanding the format of this event stream.
        if skip_this_event
          unless [:rotate_event, :format_description_event].include? event_type
            skip_event(header)
            next
          end
        end
        
        fields = read_event_fields(header)

        case event_type
        when :rotate_event
          reader.rotate(fields[:name], fields[:pos])
        when :format_description_event
          process_fde(fields)
        end

        break
      end

      {
        :type     => event_type,
        :filename => filename,
        :position => position,
        :header   => header,
        :event    => fields,
      }
    end

    # Process a format description event, which describes the version of this
    # file, and the format of events which will appear in this file. This also
    # provides the version of the MySQL server which generated this file.
    def process_fde(fde)
      if (version = fde[:binlog_version]) != 4
        raise UnsupportedVersionException.new("Binlog version #{version} is not supported")
      end

      # Save the interesting fields from an FDE so that this information is
      # available at any time later.
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
