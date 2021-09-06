#!/bin/bash

databaseinit () {
    for i in {1..50}
    do
        # Try to connect to localhost and run the init.sql script
        /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $1 -d master -i /docker-entrypoint-initdb.d/initdb/init.sql

        # If the script ran without error, we're done here.
        if [ $? -eq 0 ]
        then
            echo "====================================="
            echo "init.sql completed"
            echo "====================================="
            break
            
        # Else, make sure SQL Server is running, wait 10 seconds and try the script again
        else
            echo "====================================="
            echo "not ready yet..."
            echo "====================================="
            sleep 10s
        fi
    done
}

databaseinit $1 &
exec /opt/mssql/bin/sqlservr
