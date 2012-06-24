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

## Event Types ##

<table>
  <tr>
    <th>ID</th>
    <th>Event Type</th>
    <th>Status</th>
  </tr>
  <tr>
    <td>1</td>
    <td>start_event_v3</td>
    <td>Unsupported.</td>
  </tr>
  <tr>
    <td>2</td>
    <td>query_event</td>
    <td>Fully supported with all fields parsed.</td>
  </tr>
  <tr>
    <td>3</td>
    <td>stop_event</td>
    <td>Fully supported with all fields parsed.</td>
  </tr>
  <tr>
    <td>4</td>
    <td>rotate_event</td>
    <td>Fully supported with all fields parsed.</td>
  </tr>
  <tr>
    <td>5</td>
    <td>intvar_event</td>
    <td>Fully supported with all fields parsed.</td>
  </tr>
  <tr>
    <td>6</td>
    <td>load_event</td>
    <td>Unsupported.</td>
  </tr>
  <tr>
    <td>7</td>
    <td>slave_event</td>
    <td>Unsupported.</td>
  </tr>
  <tr>
    <td>8</td>
    <td>create_file_event</td>
    <td>Unsupported.</td>
  </tr>
  <tr>
    <td>9</td>
    <td>append_block_event</td>
    <td>Unsupported.</td>
  </tr>
  <tr>
    <td>10</td>
    <td>exec_load_event</td>
    <td>Unsupported.</td>
  </tr>
  <tr>
    <td>11</td>
    <td>delete_file_event</td>
    <td>Unsupported.</td>
  </tr>
  <tr>
    <td>12</td>
    <td>new_load_event</td>
    <td>Unsupported.</td>
  </tr>
  <tr>
    <td>13</td>
    <td>rand_event</td>
    <td>Fully supported but untested.</td>
  </tr>
  <tr>
    <td>14</td>
    <td>user_var_event</td>
    <td>Fully supported with all fields parsed.</td>
  </tr>
  <tr>
    <td>15</td>
    <td>format_description_event</td>
    <td>Fully supported with all fields parsed.</td>
  </tr>
  <tr>
    <td>16</td>
    <td>xid_event</td>
    <td>Fully supported with all fields parsed.</td>
  </tr>
  <tr>
    <td>17</td>
    <td>begin_load_query_event</td>
    <td>Unsupported.</td>
  </tr>
  <tr>
    <td>18</td>
    <td>execute_load_query_event</td>
    <td>Unsupported.</td>
  </tr>
  <tr>
    <td>19</td>
    <td>table_map_event</td>
    <td>Fully supported with all fields parsed.</td>
  </tr>
  <tr>
    <td>20</td>
    <td>pre_ga_write_rows_event</td>
    <td>Unsupported (deprecated).</td>
  </tr>
  <tr>
    <td>21</td>
    <td>pre_ga_update_rows_event</td>
    <td>Unsupported (deprecated).</td>
  </tr>
  <tr>
    <td>22</td>
    <td>pre_ga_delete_rows_event</td>
    <td>Unsupported (deprecated).</td>
  </tr>
  <tr>
    <td>23</td>
    <td>write_rows_event</td>
    <td>Partially supported.</td>
  </tr>
  <tr>
    <td>24</td>
    <td>update_rows_event</td>
    <td>Partially supported.</td>
  </tr>
  <tr>
    <td>25</td>
    <td>delete_rows_event</td>
    <td>Partially supported.</td>
  </tr>
  <tr>
    <td>26</td>
    <td>incident_event</td>
    <td>Unsupported.</td>
  </tr>
  <tr>
    <td>27</td>
    <td>heartbeat_log_event</td>
    <td>Unsupported.</td>
  </tr>
</table>
