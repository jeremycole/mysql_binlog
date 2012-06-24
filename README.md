# Library for parsing MySQL binary logs in Ruby #

This library parses a MySQL binary log in pure Ruby and produces hashes
as output, much like the following `Query` event:

    {:type=>:query_event,
     :filename=>"/Users/jeremycole/t/mysql-bin.000001",
     :header=>
      {:flags=>[],
       :timestamp=>1340414127,
       :event_type=>2,
       :server_id=>1,
       :event_length=>117,
       :next_position=>224},
     :event=>
      {:db=>"test",
       :error_code=>0,
       :status=>
        {:charset=>
          {:character_set_client=>33,
           :collation_connection=>33,
           :collation_server=>8},
         :flags2=>[],
         :catalog_nz=>"std",
         :sql_mode=>0},
       :query=>"create table a (id int, a char(100), primary key (id))",
       :thread_id=>1,
       :elapsed_time=>0},
     :position=>107}

