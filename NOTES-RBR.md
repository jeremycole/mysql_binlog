Collecting some notes about row-based replication:
* Table definition information, such as column names, are not stored in events.
* The SET and ENUM field types store internal values for the value which means that the client can't use it to construct anything useful.
* The scope of +Table_map+ events is unclear.
* The client must understand how to parse all MySQL field types. Some of them are very complex, such as DECIMAL (MYSQL_TYPE_NEWDECIMAL).
* It is not possible to skip over fields unless the client understands the packing format of the field, as the lengths are dynamic and not length-prefixed.
* The row images are not marked or tracked based on type; the client must understand the type of row event in order to understand what type of row images are appearing.