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

# Status #

Not all event types are currently supported. Over time this will improve. The
current status of event support is:

## start_event_v3 (1) ##

Unsupported.

## query_event (2) ##

Fully supported with all fields parsed.

## stop_event (3) ##

Fully supported with all fields parsed.

## rotate_event (4) ##

Fully supported with all fields parsed.

## intvar_event (5) ##

Fully supported with all fields parsed.

## load_event (6) ##

Unsupported.

## slave_event (7) ##

Unsupported.

## create_file_event (8) ##

Unsupported.

## append_block_event (9) ##

Unsupported.

## exec_load_event (10) ##

Unsupported.

## delete_file_event (11) ##

Unsupported.

## new_load_event (12) ##

Unsupported.

## rand_event (13) ##

Fully supported but untested.

## user_var_event (14) ##

Fully supported with all fields parsed.

## format_description_event (15) ##

Fully supported with all fields parsed.

## xid_event (16) ##

Fully supported with all fields parsed.

## begin_load_query_event (17) ##

Unsupported.

## execute_load_query_event (18) ##

Unsupported.

## table_map_event (19) ##
## pre_ga_write_rows_event (20) ##

Unsupported.

## pre_ga_update_rows_event (21) ##

Unsupported.

## pre_ga_delete_rows_event (22) ##

Unsupported.

## write_rows_event (23) ##

Partially supported. The main event fields are parsed, but not all row image
fields can be parsed.

## update_rows_event (24) ##

Partially supported. The main event fields are parsed, but not all row image
fields can be parsed.

## delete_rows_event (25) ##

Partially supported. The main event fields are parsed, but not all row image
fields can be parsed.

## incident_event (26) ##

Unsupported.

## heartbeat_log_event (27) ##

Unsupported.
