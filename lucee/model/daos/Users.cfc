/**
 * dbo.users dao
 */
component accessors="true" extends="model.daos.Base" singleton {

    this["meta"] = {
        "schema": "dbo",
        "tableName": "users",
        "columns": {
            "Id":           {"type": "cf_sql_integer", "primarykey": true},
            "FirstName":    {"type": "cf_sql_varchar", "required": true},
            "LastName":     {"type": "cf_sql_varchar", "required": true},
            "EmailAddress": {"type": "cf_sql_varchar", "required": true},
            "DateCreated":  {"type": "cf_sql_date"},
            "DateModified": {"type": "cf_sql_date"}
        }
    };


    /**
     * Constructor method
     *
     * @return any    An instance of this component
     */
    public model.daos.Users function init(){
        super.init();
        return this;
    }

}