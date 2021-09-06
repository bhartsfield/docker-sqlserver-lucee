/**
 * Base DAO component to provide basic single-table CRUD operations 
 */
component {

    this["meta"] = {
        "schema": "dbo",
        "tableName": "tableName",
        "columns": {}
    }

    //Constants
    TABLE_ALIAS = "_TABLE";



    /**
     * Constructor method
     *
     * @return any    An instance of this component
     */
    public any function init () {
        this["meta"]["primaryKey"] = this.meta.columns.findKey( "primaryKey" )[1].path.listFirst( "." );
        return this;
    }



    /**
     * converts a list of columns to an aliased, escaped SELECT column list
     *
     * @columns string     ?: Comma delimited list of table columns
     *
     * @return string
     */
    private string function getColumnList( string columns = this.meta.columns.keyList() ) {
        return "[#TABLE_ALIAS#].[#this.meta.primaryKey#], [#TABLE_ALIAS#].[" & replace(arguments.columns, ",", "], [#TABLE_ALIAS#].[", "all") & "]";
    }



    /**
     * Primary method for retriiving data from the table
     *
     * @columns string            ?: Comma-delimited list of columns to retrieve. If none are provided, all are returned.
     * @orderBy string            ?: The order by statement for the query. Use a comma to separate them as you normally would. The columns will be automatically aliased and escaped.
     * @filter struct             ?: A struct of columns and their values to use in the WHERE filter. Columns will be escaped and aliased so do not do it yourself.
     * @negativeFilter struct     ?: Like the filter struct but this set of columns/values will be != where fitlers will be =
     * @count boolean             ?: If true, only a count of records is returned
     * @top numeric               ?: If provided and greater than 0, the results will be limited to this number of recfords
     *
     * @return any
     */
    public any function get(
        string columns = "",
        string orderBy = this.meta.primaryKey & " ASC",
        struct filter = {},
        struct negativeFilter = {},
        boolean count = false,
        numeric top = 0
    ) {
        var _filters = "";
        var _params = {};

        local["queryOptions"] = {};
        local["columns"] = arguments.columns.len() ? getColumnList( arguments.columns ) : getColumnList();
        local["orderBy"] = arguments.count ? "" : arguments.orderBy;

        // If count is true, then we only want a count of records which means column lists and orderby do not matter
        if( arguments.count ) {
            local["columns"] = " COUNT(1) AS [count] ";
            local["orderBy"] = "";
        } else {
            // escape and alias columns in the orderBy 
            local["orderBy"] = local.orderBy.listMap( ( item ) => "[#TABLE_ALIAS#].[" & arguments.item.toString().trim().replace(" ", "] "));
        }

        // If TOP was provided, prepend the TOP filter to the select column list
        if( abs(arguments.top) ) {
            local["columns"] = " TOP (#arguments.top#) #local.columns#";
        }

        // Build the equality check where filter conditions using the provided arguments.filters
        arguments.filter.each( (columnName, value) => {
            local.condition = _filters.toString().trim().len() ? "AND" : "WHERE";

            _filters &= " #local.condition# [#TABLE_ALIAS#].[#arguments.columnName#] = :#arguments.columnName# ";
            _params[arguments.columnName] = {
                "value": arguments.value,
                "cfsqltype": this.meta.columns[arguments.columnName].type
            };
        });

        // Build the inequality check where filter conditions using the provided negativeFilters
        arguments.negativeFilter.each( (columnName, value) => {
            local.condition = _filters.toString().trim().len() ? "AND" : "WHERE";

            _filters &= " #local.condition# [#TABLE_ALIAS#].[#arguments.columnName#] != :#"not_" & arguments.columnName# ";
            _params["not_" & arguments.columnName] = {
                "value": arguments.value,
                "cfsqltype": this.meta.columns[arguments.columnName].type
            };
        });

        local["qry"] = {
            "sql": "
                SELECT 
                    #local.columns# 
                FROM 
                    [#this.meta.schema#].[#this.meta.tableName#] [#TABLE_ALIAS#]
                #_filters# 

                #len(trim(local.orderBy)) ? "ORDER BY #local.orderBy#" : ""#
                ",
            "params": _params,
            "queryoptions": local.queryOptions
        };

        // Remove any consecutive spaces or tabs from the SQL string to make it smaller when sending to the database server
        local["qry"]["sql"] = local.qry.sql.replace( "(\s|\t)+", " ", "all" );
        
        local["result"] = queryExecute( local.qry.sql, local.qry.params, local.qry.queryoptions );

        return arguments.count 
            ? local.result.count 
            : local.result;
    }



    /**
     * Uses the provided data to determine whether or not to create a new record or update an existing one
     *
     * @data struct      A struct representing the data to save
     *
     * @return query
     */
    public query function save(required struct data) {
        //if the primary key was provided and is not 0, this is an update, otherwise it is an insert
        if( arguments.data.keyExists( this.meta.primaryKey ) && (arguments.data[this.meta.primaryKey]) )
            return update( arguments.data );
        else
            return create( arguments.data );
    }



    /**
     * A private method used to create a new record using the provided data and return it. Use the save() method to create/update records.
     *
     * @data struct      A struct of columns/values to use when creating the new record
     *
     * @return query
     */
    private query function create(required struct data) {
        arguments.data = getColumnsFromStruct( arguments.data );

        local["params"] = {};
        local["requiredColumns"] = getRequiredColumns();

        local["requiredColumns"] = listToArray(lcase(structKeyList(local.requiredColumns)));
        local["requiredColumns"].removeAll(listToArray(lcase(structKeyList(arguments.data))));

        //Make sure all required columns exist in arguments.data. If they do not, throw an error
        if(arrayLen(local.requiredColumns))
            throw("Table [#this.meta.schema#].[#this.meta.tableName#] requires data for columns [#arrayToList(local.requiredColumns)#]");

        //Add params for any non-readonly columns with defaults defined. This is done first so they can be overridden with data from arguments.data
        for(local.col in this.meta.columns)
            if( this.meta.columns[local.col].keyExists( "default" ) && !(this.meta.columns[local.col].keyExists( "readonly" ) && this.meta.columns[local.col].readonly) )
                local["params"][local.col] = {
                    "value": this.meta.columns[local.col].default,
                    "cfsqltype": this.meta.columns[local.col].type
                };

        //Add (or update) params for any non-readonly using the data provided in arguments.data
        for(local.col in arguments.data)
            if(!local.col == this.meta.primaryKey && !(structKeyExists(this.meta.columns[local.col], "readonly") && this.meta.columns[local.col].readonly))
                local["params"][local.col] = {
                    "value": arguments.data[local.col],
                    "cfsqltype": this.meta.columns[local.col].type
                };
        

        local["insertColumns"] = local.params.keyList();
        local["insertValues"] = ":" & local.params.keyList().replace(",", ", :", "all");

        transaction {
            queryexecute( "INSERT INTO [#this.meta.schema#].[#this.meta.tableName#] (#insertColumns#) VALUES (#insertValues#);", params );
            local["last_id"] = queryExecute( "SELECT MAX(#this.meta.primaryKey#) AS [LAST_ID] FROM [#this.meta.schema#].[#this.meta.tableName#];" ).LAST_ID;
        }

        return get( filter={"#this.meta.primaryKey#":local.last_id} );
    }



    /**
     * Private method for updating existing records based on the provided data. Use the save() method for creating/updating records. 
     *
     * @data struct      A struct of column/values to update.
     *
     * @return query
     */
    private query function update( required struct data ) {
        arguments.data = getColumnsFromStruct( arguments.data );

        local["sets"] = "";
        local["params"] = {};

        // If the provided data doesn't include at least two columns, it is invalid (pk is required and at least one column which to update)
        if( arguments.data.count() < 2 )
            return false;

        for( local.column in arguments.data ) {
            if( local.column != this.meta.primaryKey ) {
                if( !( this.meta.columns[local.column].keyExists("readonly") && this.meta.columns[local.column].readonly ) ) {
                    local["sets"] = local.sets.listAppend( "#local.column#= :#local.column#" );
                    local["params"][local.column] = {
                        "value": arguments.data[local.column].toString().trim(), 
                        "cfsqltype": this.meta.columns[local.column].type,
                        "null": !arguments.data[local.column].toString().trim().len()
                    };
                }
            } else
                local["params"]["primaryKey"] = {
                    "value": arguments.data[local.column].toString().trim(), 
                    "cfsqltype": "cf_sql_integer"
                };
        }

        if( this.meta.columns.keyExists( "DateUpdated" ) )
            local["sets"] = local.sets.listAppend( "DateUpdated=GETDATE()" );
        
        local.qry = {
            "sql": "
                UPDATE 
                    [#this.meta.schema#].[#this.meta.tableName#]
                SET
                    #local.sets#
                WHERE
                    [#this.meta.primaryKey#] = :primaryKey
                ",
            "params": local["params"]
        };
        
        queryExecute( local.qry.sql, local.qry.params );

        return get( filter: {"#this.meta.primaryKey#":local.qry.params.primaryKey.value} );
    }



    /**
     * Deletes the record whose primaryKey value matches the provided id property's value
     *
     * @id numeric     Primary key value of the record to delete
     */
    public void function delete(required numeric id) {
        local.qry = {
            "sql": "DELETE FROM [#this.meta.schema#].[#this.meta.tableName#] WHERE [#this.meta.primaryKey#]=:id",
            "params": {
                "#this.meta.primaryKey#" : {"value":val(arguments.id), "cfsqltype":this.meta.columns[this.meta.primaryKey].type}
            }
        };

        queryExecute(local.qry.sql, local.qry.params);
    }



    /**
     * Filters the column struct down to only the required columns
     *
     * @return struct
     */
    private struct function getRequiredColumns() {
        return this.meta.columns.filter( (key, column) => column?.required==true);
    }



    /**
     * filters the prov ided struct to only the keys that are columns in the current table
     *
     * @data struct       column/value struct data
     *
     * @return struct
     */
    private struct function getColumnsFromStruct( required struct data ) {
        return arguments.data.filter( ( key ) => this.meta.columns.keyExists( key ) );
    }

}