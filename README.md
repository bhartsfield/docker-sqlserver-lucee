# BaseDao Test App With SQL Server in a Docker Container

## Overview

This is a quick proof of concept to demonstrate two items I recently mentioned to colleagues.

- The first item was that it is quite easy to spin up a SQL Server instance inside of a docker container and seed it with an initialization SQL script.
- The other item came up when I was show a number of DAOs with repetitive code for basic CRUD operations for single DB tables. The only real differences where the table names and the column lists. So, instead of duplicating everything else, a single base dao could centralize the bulk of the code and the individual DAOs could just extend it and define their table and columns.

So, I threw this together to spin up a SQL Server docker container that, when up and running, contains a test database with a users table and multiple user records.

To POC connecting to and querying that database, I created a commandbox/lucee docker container with the base DAO, a user DAO that extends the base and an index.cfm file that runs all the different CRUD operation examples.

## Starting the environment

 To start the sqlserver and lucee containers (assuming you are already running docker or docker desktop), open a command prompt of your choice, cd into the root of the project (the directory that contains the docker-compose.yml file) and run the following command.

 ```bash
 docker-compose up -d --build
 ```

Once everything is up and running (keep an eye on the lucee container logs to know when it is fully started), you should be able to open a browser and navigate to [https://localhost:8080] and see all of the CF dumps found in the inde.xcfm file.

## SQL Server

The SQL Server container is primarily defined inside the sqlserver service section of docker-compose.yml and any supporting code/files can be found in the ./sqlserver directory.

- ./sqlserver/entrypoint.sh - This is a basic bash script that will start the sqlserver process inside the container and then, once it is ready, run the init.sql script
- ./sqlserver/build/initdb/init.sql - The init.sql file is a seed script that, once the SQL Server service is running, will be ran to create a TestDb database, a dbo.users table inside that table and add multiple user records to that table.

## Lucee

The commandbox/lucee server is defined in the docker-compose.yml file under the lucee service and the application it runs is found in the ./lucee directory.

- ./lucee/Application.cfc - his is a very basic Application.cfc file that just defines the application name and a datasource that points to the sqlserver docker container's TestDb database
- ./lucee/box.json - The box.json file is also a very basic one. It simply defines the SQL Server jdbc driver as the only server dependency and then runs the box "install" command when the new Lucee server installs the first time.
- ./lucee/model/daos/Base.cfc - The base dao is meant to be extended by single-table DAOs (such as the users.cfc). It provides basic CRUD functionality with various filtering and ordering options.
- ./lucee/model/daos/Users.cfc - This is a minimal example of a table-specific DAO that represents the TestDb.dbo.Users table that the init.sql script created in the sqlserver docker container. It extends the Base.cfc DAO in order to gain the basic CRUD functionality.
- ./lucee/index.cfm - Index.cfm just creates an instance of the User dao and then performs all of the available create, read, update, delete, filtering and ordering functionality provided by the base DAO.

Examples in index.cfm (from the top down) are

- Creates a new user record using data from randomuser.me
- Reads all user records ordered by the primary key ASC (the default ordering method)
- Reads the user record with an Id of 1
- Reads a count of user records
- Reads a count of user records where the LastName is "Turk"
- Reads all user records ordered by LastName ASC then FirstName ASC
- Reads all user records where the LastName is NOT "Turk"
- Reads the top 1 record ordered by Id DESC
- Updates the latest user record's FirstName, LastName and EmailAddress to random values from randomuser.me
- Reads the top 1 record ordered by Id DESC (to confirm the updates)
- Deletes the newest user record

## ./docker-compose.yml

The docker-compose file is what defines the environment (which just consists of a database server and a lucee server). Below is a breakdown of its contents.

### volumes

First, a volume named sqlserver_vol is created in which to store the database files we want to persist. If the data is not persisted in a volume outside of the container, it would all be lost each time the container is restarted.

### networks

In order for the services within our docker environment to communicate with each other, a virtual docker network needs to be defined. In this case, there is just one simple network named "main".

### services

This is where all the different containers are defined. In this case, only two services are defined, a SQL Server container and a Lucee container.

### sqlserver

- image: mcr.microsoft.com/mssql/server:2019-latest is the official Microsoft SQL Server 2019 docker image so it is what we use to run our SQL Server instance
- hostname: When running multiple containers that need to communicate with each other, they can resolve each other by their defined hostnames.
- exposes: The default SQL Server connection port is 1433. Since we want to allow the lucee service to connect to the sqlserver container's sql instance, port 1433 (which is the SQL Server default port) needs to be exposed.
- ports: 1433:1433 just says to map the host port of 1433 to the exposed container port of 1433. This is only necessary when you want an external connection into the sql server instance. For example, if you want to use SSM from your own machine to connect to the SQL instance, a host port needs to be mapped to the internal exposed port. In this particular case, 1433 was used for both but the host port (left side of the colon) could be any available port on the host.
- environment: Here you can define environment variables that end up being environment variables within the container. ACCEPT_EULA and SA_PASSWORD are environment variables are built into the official SQL Server docker image and, if provided, are automatically picked up/used by the setup scripts inside the container.
- volumes: Here we map the /var/opt/mssql path within the contain to the external, persisted sqlserver_vol volume created under the volumes section of the docker-compose file. Next, we caopy the contents of ./sqlserver/build from our code into the container at /docker-entrypoint-initdb.d.
- command: The command(s) provided here will be ran inside the container when it starts up. In this example, we're making the entrypoint.sh file executable and then running it and passing our database password in as the only argument.
- network: here, we are just telling the container which virtual docker network in which to put the container (which is the "main" network we created at the top of the docker-compose file) and then telling it.
- healthcheck: the healthcheck option allows you to define a command to be used to test the container's state. Since we have another service that depends on the sqlserver service, we needed a way to tell that service that sqlserver was actually ready for connections.

### lucee

- image: ortussolutions/commandbox:lucee-light-alpine-3.4.0 is an official prewarmed ortus solutions commandbox/lucee image
- env_file: this is the alternative to the environments setting from the sqlserver example above (though they can be used in conjunction). Instead of defining environment variables directly in the docker-compose file, you can also define them in an environment file then use env_file and provide it here.
- volumes: here we are just mounting the local ./lucee directory to the /app directory int he container (this does not copy the files into the image/container, it just mounts them so you can change the files locally and see those changes reflected inside the container immediately).
- network: here, we are just telling the container which virtual docker network in which to put the container (which is the "main" network we created at the top of the docker-compose file)
- expose: The official ortus image runs the Lucee instance on port 8080. In order to access the lucee instance from outside the container, port 8080 is exposed.
- ports: To round out the ability to access the container's Lucee instance, the exposed 8080 port is mapped to a port on the host (in this case, we are just using port 8080 there as well. If you want to use a different host port, change the left side of the colon to that port)
- depends_on: The "depends_on" setting is a method for telling a service it must wait on another to be ready before starting. In this case, the lucee service will wait on the sqlservice's healthcheck to be true to satisfy the dependency.
restart: This just tells the service to restart when it goes down due to a failure.

### .env

The .env file is where you define environment variables. Docker-compose and commandbox-dotenv can both read and load this file so any environment variables defined within will be not only be available to the SQL Server docker container form above but also available to your CF application.

The contents of this particular .env file is just defining details for setting up the sqlserver database and for telling the Lucee instance how to connect to it.
