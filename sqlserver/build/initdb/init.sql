IF ( DB_ID('TestDb') IS NULL )
    CREATE DATABASE TestDb;

GO

IF NOT EXISTS(SELECT 1 FROM sys.tables WHERE name = 'users')
    CREATE TABLE [TestDb].[dbo].[users]
    (
        Id INT PRIMARY KEY IDENTITY(1,1),
        FirstName VARCHAR(20) NOT NULL, 
        LastName VARCHAR(20) NOT NULL,
        EmailAddress VARCHAR(150) NOT NULL,
        DateCreated DATETIME NOT NULL DEFAULT GETDATE(),
        DateModified DATETIME NULL
    )

GO

TRUNCATE TABLE [TestDb].[dbo].[users]

GO

INSERT INTO [TestDb].[dbo].[users] (FirstName,LastName,EmailAddress) SELECT 'Christopher', 'Turk', 'christopher.turk@sacredheart.com'
INSERT INTO [TestDb].[dbo].[users] (FirstName,LastName,EmailAddress) SELECT 'Carla', 'Turk', 'carla.turk@sacredheart.com'
INSERT INTO [TestDb].[dbo].[users] (FirstName,LastName,EmailAddress) SELECT 'Elliot', 'Reid', 'elliot.reid@sacredheart.com'
INSERT INTO [TestDb].[dbo].[users] (FirstName,LastName,EmailAddress) SELECT 'Perry', 'Cox', 'perry.cox@sacredheart.com'
INSERT INTO [TestDb].[dbo].[users] (FirstName,LastName,EmailAddress) SELECT 'Jan', 'Itor', 'jan.itor@sacredheart.com'

