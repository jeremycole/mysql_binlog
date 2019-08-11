# Library for parsing MySQL binary logs in Ruby #

This library parses a MySQL binary log in pure Ruby and produces hashes as output, much like the following `Query` event:

```
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
```

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
    <td>write_rows_event_v1</td>
    <td>Fully supported with all fields parsed.</td>
  </tr>
  <tr>
    <td>24</td>
    <td>update_rows_event_v1</td>
    <td>Fully supported with all fields parsed.</td>
  </tr>
  <tr>
    <td>25</td>
    <td>delete_rows_event_v1</td>
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
    <td>28</td>
    <td>ignorable_log_event</td>
    <td>Unsupported.</td>
  </tr>
  <tr>
    <td>29</td>
    <td>rows_query_log_event</td>
    <td>Fully supported with all fields parsed.</td>
  </tr>
  <tr>
    <td>30</td>
    <td>write_rows_event_v2</td>
    <td>Fully supported with all fields parsed.</td>
  </tr>
  <tr>
    <td>31</td>
    <td>update_rows_event_v2</td>
    <td>Fully supported with all fields parsed.</td>
  </tr>
  <tr>
    <td>32</td>
    <td>delete_rows_event_v2</td>
    <td>Fully supported with all fields parsed.</td>
  </tr>
  <tr>
    <td>33</td>
    <td>gtid_log_event</td>
    <td>Fully supported with all fields parsed.</td>
  </tr>
  <tr>
    <td>34</td>
    <td>anonymous_gtid_log_event</td>
    <td>Fully supported with all fields parsed.</td>
  </tr>
  <tr>
    <td>35</td>
    <td>previous_gtids_log_event</td>
    <td>Fully supported with all fields parsed.</td>
  </tr>
  <tr>
    <td>36</td>
    <td>transaction_context_event</td>
    <td>Unsupported.</td>
  </tr>
  <tr>
    <td>37</td>
    <td>view_change_event</td>
    <td>Unsupported.</td>
  </tr>
  <tr>
    <td>38</td>
    <td>xa_prepare_log_event</td>
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
    <th>ID</th>
    <th>SQL Data Type</th>
    <th>MySQL Internal Type</th>
    <th>Status</th>
  </tr>
  <tr>
    <th colspan=4>Numeric Types</th>
  </tr>
  <tr>
    <td>1</td>
    <td>TINYINT</td>
    <td>MYSQL_TYPE_TINY</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>2</td>
    <td>SMALLINT</td>
    <td>MYSQL_TYPE_SHORT</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>9</td>
    <td>MEDIUMINT</td>
    <td>MYSQL_TYPE_INT24</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>3</td>
    <td>INT</td>
    <td>MYSQL_TYPE_LONG</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>8</td>
    <td>BIGINT</td>
    <td>MYSQL_TYPE_LONGLONG</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>4</td>
    <td>FLOAT</td>
    <td>MYSQL_TYPE_FLOAT</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>5</td>
    <td>DOUBLE</td>
    <td>MYSQL_TYPE_DOUBLE</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>246</td>
    <td>DECIMAL</td>
    <td>MYSQL_TYPE_NEWDECIMAL</td>
    <td>Fully supported using BigDecimal.</td>
  </tr>
  <tr>
    <th colspan=4>Temporal Types</th>
  </tr>
  <tr>
    <td>7</td>
    <td>TIMESTAMP</td>
    <td>MYSQL_TYPE_TIMESTAMP</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>17</td>
    <td>TIMESTAMP(<i>n</i>)</td>
    <td>MYSQL_TYPE_TIMESTAMP2</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>12</td>
    <td>DATETIME</td>
    <td>MYSQL_TYPE_DATETIME</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>18</td>
    <td>DATETIME(<i>n</i>)</td>
    <td>MYSQL_TYPE_DATETIME2</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>10</td>
    <td>DATE</td>
    <td>MYSQL_TYPE_DATE</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>14</td>
    <td>DATE</td>
    <td>MYSQL_TYPE_NEWDATE</td>
    <td>Unsupported.</td>
  </tr>
  <tr>
    <td>11</td>
    <td>TIME</td>
    <td>MYSQL_TYPE_TIME</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>19</td>
    <td>TIME(<i>n</i>)</td>
    <td>MYSQL_TYPE_TIME2</td>
    <td>Unsupported.</td>
  </tr>
  <tr>
    <td>13</td>
    <td>YEAR</td>
    <td>MYSQL_TYPE_YEAR</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <th colspan=4>String Types</th>
  </tr>
  <tr>
    <td>15<br/>253<br/>254</td>
    <td>CHAR<br/>VARCHAR</td>
    <td>MYSQL_TYPE_STRING</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <td>249<br/>252<br/>250<br/>251</td>
    <td>TINYBLOB<br/>BLOB<br/>MEDIUMBLOB<br/>LONGBLOB</td>
    <td>MYSQL_TYPE_BLOB</td>
    <td>Fully supported.</td>
  </tr>
  <tr>
    <th colspan=4>Other Types</th>
  </tr>
  <tr>
    <td>247</td>
    <td>ENUM</td>
    <td>MYSQL_TYPE_STRING</td>
    <td>Supported, but values returned are internal representations.</td>
  </tr>
  <tr>
    <td>248</td>
    <td>SET</td>
    <td>MYSQL_TYPE_STRING</td>
    <td>Supported, but values returned are internal representations.</td>
  </tr>
  <tr>
    <td>16</td>
    <td>BIT</td>
    <td>MYSQL_TYPE_BIT</td>
    <td>Supported, treated as integer of appropriate size.</td>
  </tr>
  <tr>
    <td>255</td>
    <td>GEOMETRY</td>
    <td>MYSQL_TYPE_GEOMETRY</td>
    <td>Supported, treated as BLOB.</td>
  </tr>
  <tr>
    <td>245</td>
    <td>JSON</td>
    <td>MYSQL_TYPE_JSON</td>
    <td>Supported, treated as BLOB.</td>
  </tr>
</table>
