Gem::Specification.new do |s|
  s.name        = 'mysql_binlog'
  s.version     = File.open("VERSION").readline.chomp
  s.date        = Time.now.strftime("%Y-%m-%d")
  s.summary     = 'MySQL Binary Log Parser'
  s.description = 'Library for parsing MySQL binary logs in Ruby'
  s.authors     = [ 'Jeremy Cole' ]
  s.email       = 'jeremy@jcole.us'
  s.homepage    = 'http://jcole.us/'
  s.files = [
    'lib/mysql_binlog.rb',
    'lib/mysql_binlog/binlog.rb',
    'lib/mysql_binlog/binlog_event_parser.rb',
    'lib/mysql_binlog/binlog_field_parser.rb',
    'lib/mysql_binlog/mysql_character_set.rb',
    'lib/mysql_binlog/reader/binlog_file_reader.rb',
    'lib/mysql_binlog/reader/binlog_stream_reader.rb',
    'lib/mysql_binlog/reader/debugging_reader.rb',
  ]
  s.executables = [
    'mysql_binlog_dump',
  ]
end
