/* =====================================================================
   DataRetail 360 · EP3 IDY1102
   00 · Creación de la base de datos y de los esquemas Medallion
   Ejecutar en SSMS una sola vez, antes del notebook 02.
   ===================================================================== */
IF DB_ID('DataRetail360') IS NULL
    CREATE DATABASE DataRetail360;
GO

USE DataRetail360;
GO

-- Bronze: copia fiel de la fuente · Silver: datos limpios y validados
-- Gold: modelo dimensional · Audit: trazabilidad de ejecuciones
IF SCHEMA_ID('bronze') IS NULL EXEC('CREATE SCHEMA bronze');
IF SCHEMA_ID('silver') IS NULL EXEC('CREATE SCHEMA silver');
IF SCHEMA_ID('gold')   IS NULL EXEC('CREATE SCHEMA gold');
IF SCHEMA_ID('audit')  IS NULL EXEC('CREATE SCHEMA audit');
GO

SELECT name AS esquema FROM sys.schemas WHERE name IN ('bronze', 'silver', 'gold', 'audit');
