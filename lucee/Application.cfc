component {
    this["name"] = 'baseDaoTest';
    this["datasources"] = {
        "TestDb": {
            "class": "com.microsoft.sqlserver.jdbc.SQLServerDriver",
            "connectionString": "jdbc:sqlserver://#server.system.environment["DATABASE_SERVER"]#:1433;DATABASENAME=#server.system.environment["DATABASE_NAME"]#;sendStringParametersAsUnicode=true;SelectMethod=direct",
            "username": server.system.environment["DATABASE_USER"],
            "password": server.system.environment["DATABASE_PASSWORD"],
            "blob":true,
            "clob":true,
            "connectionLimit":"100",
            "validate":false,
            "timezone":"America/New_York"
        }
    };
    this["datasource"] = "TestDb";
}
