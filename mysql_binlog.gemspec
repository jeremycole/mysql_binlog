lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
require "mysql_binlog/version"

Gem::Specification.new do |s|
  s.name        = 'mysql_binlog'
  s.version     = MysqlBinlog::VERSION
  s.date        = Time.now.strftime("%Y-%m-%d")
  s.summary     = 'MySQL Binary Log Parser'
  s.license     = 'BSD-3-Clause'
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
    'lib/mysql_binlog/version.rb',
  ]
  s.executables = [
    'mysql_binlog_dump',
    'mysql_binlog_summary',
  ]
end
