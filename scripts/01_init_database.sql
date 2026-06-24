/*
=================================
Create Database and Schemas
=================================
Script Purpose:
    This script creates a new database named 'DataWarehouse' after
    checking if it already exists. If the database exists, it is 
    dropped and recreated. Additionally, the script sets up three schemas
    within the database: 'bronze', 'silver', 'gold'.

Warning:
    Running this script will drop the entire 'DataWarehouse' database if it exists.
    All data in the database will be permanently deleted. Proceed with caution and
    ensure you have proper backups before running the script.
*/

--Drop and recreate the 'DataWarehouse' database
DROP DATABASE IF EXISTS "DataWarehouse" WITH (FORCE);

--CREATE the 'DataWarehouse' DATABASE;
CREATE DATABASE DataWarehouse;

--Create Schemas
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver; 
CREATE SCHEMA IF NOT EXISTS gold;