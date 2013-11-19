module MysqlBinlog
  # This version of the binary log format is not supported by this library.
  class UnsupportedVersionException < Exception; end

  # This field type is not supported by this library.
  class UnsupportedTypeException < Exception; end

  # An error was encountered when trying to read the log, which was likely
  # due to garbage data in the log. Continuing is likely impossible.
  class MalformedBinlogException < Exception; end

  # When attempting a read, no data was returned.
  class ZeroReadException < Exception; end

  # When attempting a read, fewer bytes of data were returned than were
  # requested by the reader, likely indicating a truncated file or corrupted
  # event.
  class ShortReadException < Exception; end

  # After an event or other structure was fully read, the log position exceeded
  # the end of the structure being read. This would indicate a bug in parsing
  # the fields in the structure. For example, reading garbage data for a length
  # field may cause a string read based on that length to read data well past
  # the end of the event or structure. This is essentially always fatal.
  class OverReadException < Exception; end

  # Read a binary log, parsing and returning events.
  #
  # == Examples
  #
  # A basic example of using the Binlog class:
  #
  #   require 'mysql_binlog'
  #   include MysqlBinlog
  #
  #   # Open a binary log from a file on disk.
  #   binlog = Binlog.new(BinlogFileReader.new("mysql-bin.000001"))
  #
  #   # Iterate over all events from the log, printing the event type (such
  #   # as :query_event, :write_rows_event, etc.)
  #   binlog.each_event do |event|
  #     puts event[:type]
  #   end
  #
  class Binlog
    attr_reader :fde
    attr_accessor :reader
    attr_accessor :field_parser
    attr_accessor :event_parser
    attr_accessor :filter_event_types
    attr_accessor :filter_flags
    attr_accessor :ignore_rotate
    attr_accessor :max_query_length

    def initialize(reader)
      @reader = reader
      @field_parser = BinlogFieldParser.new(self)
      @event_parser = BinlogEventParser.new(self)
      @fde = nil
      @filter_event_types = nil
      @filter_flags = nil
      @ignore_rotate = false
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
    private :skip_event

    # Read the content of the event, which follows the header.
    def read_event_fields(header)
      # Delegate the parsing of the event content to a method of the same name
      # in BinlogEventParser.
      if event_parser.methods.include? header[:event_type].to_s
        fields = event_parser.send(header[:event_type], header)
      end

      # Check if we've read past the end of the event. This is normally because
      # of an unsupported substructure in the event causing field misalignment
      # or a bug in the event reader method in BinlogEventParser. This may also
      # be due to user error in providing an initial start position or later
      # seeking to a position which is not a valid event start position.
      if reader.position > header[:next_position]
        raise OverReadException.new("Read past end of event; corrupted event, bad start position, or bug in mysql_binlog?")
      end

      # Anything left unread at this point is skipped based on the event length
      # provided in the header. In this way, it is possible to skip over events
      # that are not able to be parsed completely by this library.
      skip_event(header)

      fields
    end
    private :read_event_fields

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

        # Skip the remaining part of the header which might not have been
        # parsed.
        if @fde
          reader.seek(position + @fde[:header_length])
        end

        if @filter_event_types
          unless @filter_event_types.include? header[:event_type]
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
          unless [:rotate_event, :format_description_event].include? header[:event_type]
            skip_event(header)
            next
          end
        end

        fields = read_event_fields(header)

        case header[:event_type]
        when :rotate_event
          unless ignore_rotate
            reader.rotate(fields[:name], fields[:pos])
          end
        when :format_description_event
          process_fde(fields)
        end

        break
      end

      {
        :type     => header[:event_type],
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
    private :process_fde

    # Iterate through all events.
    def each_event
      unless block_given?
        return Enumerable::Enumerator.new(self, :each_event)
      end

      while event = read_event
        yield event
      end
    end
  end
end
