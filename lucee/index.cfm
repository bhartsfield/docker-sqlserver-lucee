<cfscript>
    userDao = new model.daos.Users();

    // Create a new user
    randomUser = deserializeJson( new http(url="https://randomuser.me/api/?inc=name,email").send().getPrefix().fileContent ).results[1];
    userDao.save( {
        "firstName": randomUser.name.first,
        "lastName": randomUser.name.last,
        "emailAddress": randomUser.email
    } );

    // all data ordered by primary key
    writeDump( userDao.get() );

    // record with primary key value of 1
    writeDump( userDao.get( filter: {"Id": 1} ) );

    // Count of all records
    writeDump( userDao.get( count:true ) );

    // Count of all records with a last name of "turk"
    writeDump( userDao.get( count:true, filter: {"LastName": "Turk"} ) );

    // All users ordered by last name ascending then first name ascending
    writeDump( userDao.get( orderBy:"LastName ASC, FirstName ASC" ) );

    // All users whose last name is NOT Turkl
    writeDump( userDao.get( negativeFilter: {"LastName": "Turk"} ) );

    // Get the first record ordered by Id desc
    newestUser =  userDao.get( top: 1, orderBy: "Id DESC" );
    writeDump( newestUser );


    // Update the newest user's first and last name 
    randomUser = deserializeJson( new http(url="https://randomuser.me/api/?inc=name,email").send().getPrefix().fileContent ).results[1];
    writeDump( userDao.save( {
        "id": newestUser.id,
        "firstName": randomUser.name.first,
        "lastName": randomUser.name.last,
        "emailAddress": randomUser.email
    } ) );


    writeDump( userDao.get( top: 1, orderBy: "Id DESC" ) );
    
    // Delete the newest record
    userDao.delete(id: newestUser.id);



    
</cfscript>