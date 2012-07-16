# Library for parsing MySQL binary logs in Ruby #

This library parses a MySQL binary log in pure Ruby and produces hashes as output, much like the following `Query` event:

    {:type=>:query_event,
     :position=>107,
     :filename=>"mysql-bin.000001",
     :header=>
      {:event_type=>2,
       :server_id=>1,
       :flags=>[],
       :event_length=>117,
       :timestamp=>1340414127,
       :next_position=>224},
     :event=>
      {:thread_id=>1,
       :query=>"create table a (id int, a char(100), primary key (id))",
       :status=>
        {:sql_mode=>0,
         :charset=>
          {:character_set_client=>
            {:character_set=>:utf8, :collation=>:utf8_general_ci},
           :collation_connection=>
            {:character_set=>:utf8, :collation=>:utf8_general_ci},
           :collation_server=>
            {:character_set=>:latin1, :collation=>:latin1_swedish_ci}},
         :flags2=>[],
         :catalog=>"std"},
       :elapsed_time=>0,
       :error_code=>0,
       :db=>"test"}}

# Status #

All event types can be read, but may not be parsed, as not all event types are currently fully supported. Over time this will improve. The current status of event support is documented below.

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
    <td>Unsupported (deprecated).</td>
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
    <td>Unsupported (deprecated).</td>
  </tr>
  <tr>
    <td>7</td>
    <td>slave_event</td>
    <td>Unsupported (deprecated).</td>
  </tr>
  <tr>
    <td>8</td>
    <td>create_file_event</td>
    <td>Unsupported (deprecated).</td>
  </tr>
  <tr>
    <td>9</td>
    <td>append_block_event</td>
    <td>Unsupported.</td>
  </tr>
  <tr>
    <td>10</td>
    <td>exec_load_event</td>
    <td>Unsupported (deprecated).</td>
  </tr>
  <tr>
    <td>11</td>
    <td>delete_file_event</td>
    <td>Unsupported.</td>
  </tr>
  <tr>
    <td>12</td>
    <td>new_load_event</td>
    <td>Unsupported (deprecated).</td>
  </tr>
  <tr>
    <td>13</td>
    <td>rand_event</td>
    <td>Fully supported with all fields parsed.</td>
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
    <td>Fully supported with all fields parsed.</td>
  </tr>
  <tr>
    <td>24</td>
    <td>update_rows_event</td>
    <td>Fully supported with all fields parsed.</td>
  </tr>
  <tr>
    <td>25</td>
    <td>delete_rows_event</td>
    <td>Fully supported with all fields parsed.</td>
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
  <tr>
    <td>50</td>
    <td>table_metadata_event</td>
    <td>Specific to Twitter MySQL 5.5.24.t7+. Fully supported with all fields parsed.</td>
  </tr>
</table>

## Data Types Supported in Row Events ##

<table>
  <tr>
    <th>Data Type</th>
    <th>Binlog Type</th>
    <th>Status</th>
  </tr>
  <tr>
    <th colspan=3>Numeric Types</th>
  </tr>
  <tr>
    <td>TINYINT</td>
    <td>MYSQL_TYPE_TINY</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>SMALLINT</td>
    <td>MYSQL_TYPE_SHORT</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>MEDIUMINT</td>
    <td>MYSQL_TYPE_INT24</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>INT</td>
    <td>MYSQL_TYPE_LONG</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>BIGINT</td>
    <td>MYSQL_TYPE_LONGLONG</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>FLOAT</td>
    <td>MYSQL_TYPE_FLOAT</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>DOUBLE</td>
    <td>MYSQL_TYPE_DOUBLE</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>DECIMAL</td>
    <td>MYSQL_TYPE_NEWDECIMAL</td>
    <td>Fully supported using BigDecimal.</td>
  </tr>
  <tr>
    <th colspan=3>Temporal Types</th>
  </tr>
  <tr>
    <td>TIMESTAMP</td>
    <td>MYSQL_TYPE_TIMESTAMP</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>DATETIME</td>
    <td>MYSQL_TYPE_DATETIME</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>DATE</td>
    <td>MYSQL_TYPE_DATE</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>TIME</td>
    <td>MYSQL_TYPE_TIME</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>YEAR</td>
    <td>MYSQL_TYPE_YEAR</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <th colspan=3>String Types</th>
  </tr>
  <tr>
    <td>CHAR<br/>VARCHAR</td>
    <td>MYSQL_TYPE_STRING</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>TINYBLOB<br/>BLOB<br/>MEDIUMBLOB<br/>LONGBLOB</td>
    <td>MYSQL_TYPE_BLOB</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <th colspan=3>Other Types</th>
  </tr>
  <tr>
    <td>ENUM</td>
    <td>MYSQL_TYPE_STRING</td>
    <td>Supported, but values returned are internal representations.</td>
  </tr>
  <tr>
    <td>SET</td>
    <td>MYSQL_TYPE_STRING</td>
    <td>Supported, but values returned are internal representations.</td>
  </tr>
  <tr>
    <td>BIT</td>
    <td>MYSQL_TYPE_BIT</td>
    <td>Supported, treated as integer of appropriate size.</td>
  </tr>
  <tr>
    <td>GEOMETRY</td>
    <td>MYSQL_TYPE_GEOMETRY</td>
    <td>Supported, treated as BLOB.</td>
  </tr>
</table>
