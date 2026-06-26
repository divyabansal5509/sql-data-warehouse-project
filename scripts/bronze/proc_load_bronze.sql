/*
========================================================================
Stored Procedure: Load Bronze Layer (Source-> Bronze)
========================================================================
    This stored procedure loads data into the 'bronze' schema from external CSV files.
    - Truncates the bronze tables before loading data.
    - Uses the 'COPY' command to load data from csv files to bronze tables.

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Usage Examples:
    CALL bronze.load_bronze;
========================================================================
*/

--Truncate and BULK INSERT
--Write SQL COPY Insert to load all CSV files into your bronze tables.

--Create Stored Procedure
CREATE OR REPLACE PROCEDURE bronze.load_bronze()
LANGUAGE plpgsql
AS $$
DECLARE
    v_start_time TIMESTAMPTZ;
    v_end_time TIMESTAMPTZ;
    v_duration INTERVAL;
    batch_start_time TIMESTAMPTZ;
BEGIN
batch_start_time := clock_timestamp();

    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Loading Bronze Layer';
    RAISE NOTICE '=================================================';

    RAISE NOTICE '-------------------------------------------------';
    RAISE NOTICE 'Loading CRM Tables';
    RAISE NOTICE '-------------------------------------------------';

    --Load data

    v_start_time := clock_timestamp();

    RAISE NOTICE '>> Truncating Table: bronze.crm_cust_info';
    TRUNCATE TABLE bronze.crm_cust_info;

    RAISE NOTICE '>> Insert Data Into: bronze.crm_cust_info';
    COPY bronze.crm_cust_info
    FROM 'C:\Users\Lenovo\Desktop\SQL\sql-data-warehouse\sql-data-warehouse-project\datasets\source_crm\cust_info.csv'
    WITH(
        FORMAT CSV,
        HEADER true,
        DELIMITER ','
    );
    v_duration := clock_timestamp() - v_start_time;
    RAISE NOTICE 'Load Duration: %', v_duration;
    RAISE NOTICE '-------------------';

    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: bronze.crm_prd_info';
    TRUNCATE TABLE bronze.crm_prd_info;

    RAISE NOTICE '>> Insert Data Into: bronze.crm_prd_info';
    COPY bronze.crm_prd_info
    FROM 'C:\Users\Lenovo\Desktop\SQL\sql-data-warehouse\sql-data-warehouse-project\datasets\source_crm\prd_info.csv'
    WITH(
        FORMAT CSV,
        HEADER true,
        DELIMITER ','
    );
    v_duration := clock_timestamp() - v_start_time;
    RAISE NOTICE 'Load Duration: %', v_duration;
    RAISE NOTICE '-------------------';

    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: bronze.crm_sales_details';
    TRUNCATE TABLE bronze.crm_sales_details;

    RAISE NOTICE '>> Insert Data Into: bronze.crm_sales_details';
    COPY bronze.crm_sales_details
    FROM 'C:\Users\Lenovo\Desktop\SQL\sql-data-warehouse\sql-data-warehouse-project\datasets\source_crm\sales_details.csv'
    WITH(
        FORMAT CSV,
        HEADER true,
        DELIMITER ','
    );
    v_duration := clock_timestamp() - v_start_time;
    RAISE NOTICE 'Load Duration: %', v_duration;
    RAISE NOTICE '-------------------';

    RAISE NOTICE '-------------------------------------------------';
    RAISE NOTICE 'Loading ERP Tables';
    RAISE NOTICE '-------------------------------------------------';

    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: bronze.erp_cust_az12';
    TRUNCATE TABLE bronze.erp_cust_az12;

    RAISE NOTICE '>> Insert Data Into: bronze.erp_cust_az12';
    COPY bronze.erp_cust_az12
    FROM 'c:\Users\Lenovo\Desktop\SQL\sql-data-warehouse\sql-data-warehouse-project\datasets\source_erp\CUST_AZ12.csv'
    WITH(
        FORMAT CSV,
        HEADER true,
        DELIMITER ','
    );
    v_duration := clock_timestamp() - v_start_time;
    RAISE NOTICE 'Load Duration: %', v_duration;
    RAISE NOTICE '-------------------';

    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: bronze.erp_loc_a101';
    TRUNCATE TABLE bronze.erp_loc_a101;

    RAISE NOTICE '>> Insert Data Into: bronze.erp_loc_a101';
    COPY bronze.erp_loc_a101
    FROM 'c:\Users\Lenovo\Desktop\SQL\sql-data-warehouse\sql-data-warehouse-project\datasets\source_erp\LOC_A101.csv'
    WITH(
        FORMAT CSV,
        HEADER true,
        DELIMITER ','
    );
    v_duration := clock_timestamp() - v_start_time;
    RAISE NOTICE 'Load Duration: %', v_duration;
    RAISE NOTICE '-------------------';

    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: bronze.erp_px_cat_g1v2';
    TRUNCATE TABLE bronze.erp_px_cat_g1v2;

    RAISE NOTICE '>> Insert Data Into: bronze.erp_px_cat_g1v2'; 
    COPY bronze.erp_px_cat_g1v2
    FROM 'c:\Users\Lenovo\Desktop\SQL\sql-data-warehouse\sql-data-warehouse-project\datasets\source_erp\PX_CAT_G1V2.csv'
    WITH(
        FORMAT CSV,
        HEADER true,
        DELIMITER ','
    );
    v_duration := clock_timestamp() - v_start_time;
    RAISE NOTICE 'Load Duration: %', v_duration;
    RAISE NOTICE '-------------------';

    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Bronze Layer Loading Completed Successfully';
    RAISE NOTICE '=================================================';
 
v_duration := clock_timestamp()-batch_start_time;

RAISE NOTICE '=================================================';
RAISE NOTICE 'Total Bronze Load Duration: %', v_duration;
RAISE NOTICE '=================================================';

EXCEPTION 
    WHEN OTHERS THEN
        RAISE NOTICE '==========================================';
        RAISE NOTICE 'ERROR OCCURRED DURING LOADING BRONZE LAYER';
        RAISE WARNING 'Error Message: %',SQLERRM;
        RAISE WARNING 'SQLSTATE: %', SQLSTATE;
        RAISE NOTICE '==========================================';
END;
$$; 

CALL bronze.load_bronze();  
