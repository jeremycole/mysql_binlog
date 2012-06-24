Gem::Specification.new do |s|
  s.name        = 'mysql_binlog'
  s.version     = '0.1.0'
  s.date        = '2012-06-24'
  s.summary     = 'MySQL Binary Log Parser'
  s.description = 'Library for parsing MySQL binary logs in Ruby'
  s.authors     = [ 'Jeremy Cole' ]
  s.email       = 'jeremy@jcole.us'
  s.homepage    = 'http://jcole.us/'
  s.files = [
    'lib/mysql_binlog.rb',
    'lib/mysql_binlog/mysql_binlog.rb',
    'lib/mysql_binlog/binlog_parser.rb',
    'lib/mysql_binlog/binlog_event_field_parser.rb',
    'lib/mysql_binlog/reader/binlog_file_reader.rb',
    'lib/mysql_binlog/reader/binlog_stream_reader.rb',
  ]
  s.executables = [
    'mysql_binlog_dump',
  ]
end
