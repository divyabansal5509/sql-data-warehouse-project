/*
========================================================================
Stored Procedure: Load Silver Layer (Bronze-> Silver)
========================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract,Transform,Load) process to
    populate the 'silver' schema from the 'bronze' schema.
Actions Performed:
    - Truncates the silver tables.
    - Inserts transformed and cleaned data from Bronze into Silver tables.

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Usage Examples:
    CALL silver.load_bronze();
========================================================================
*/

CREATE OR REPLACE PROCEDURE silver.load_silver()
LANGUAGE plpgsql
AS $$
DECLARE
    v_start_time TIMESTAMPTZ;
    v_duration INTERVAL;
    batch_start_time TIMESTAMPTZ;
BEGIN
batch_start_time := clock_timestamp();

    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Loading Silver Layer';
    RAISE NOTICE '=================================================';

    RAISE NOTICE '-------------------------------------------------';
    RAISE NOTICE 'Loading CRM Tables';
    RAISE NOTICE '-------------------------------------------------';

    --Loading data

    v_start_time := clock_timestamp();

    RAISE NOTICE '>> Truncating Table : silver.crm_cust_info';
    TRUNCATE TABLE silver.crm_cust_info;
    RAISE NOTICE '>> Inserting data Into: silver.crm_cust_info';
    INSERT INTO silver.crm_cust_info(
        cst_id,
        cst_key,
        cst_firstname,
        cst_lastname,
        cst_marital_status,
        cst_gndr,
        cst_create_date
    )
    SELECT 
        cst_id,
        cst_key,
        TRIM(cst_firstname) AS cst_firstname,
        TRIM(cst_lastname) AS cst_lastname,
        CASE
            WHEN UPPER(TRIM(cst_marital_status)) ='S' THEN 'Single'
            WHEN UPPER(TRIM(cst_marital_status)) ='M' THEN 'Married'
            ELSE 'n/a' 
        END cst_marital_status, --Normalize marital status values to readable format
        CASE
            WHEN UPPER(TRIM(cst_gndr)) ='F' THEN 'Female'
            WHEN UPPER(TRIM(cst_gndr)) ='M' THEN 'Male'
            ELSE 'n/a'
        END cst_gndr,           --Normalize gender values to readable format
        cst_create_date
    from(
        SELECT
            *,
            row_number() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) as flag_last
        FROM bronze.crm_cust_info
    )t WHERE flag_last =1 ;     --Select the most record per customer

    v_duration := clock_timestamp() - v_start_time;
    RAISE NOTICE 'Load Duration: %', v_duration;
    RAISE NOTICE '-------------------';

    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table : silver.crm_prd_info';
    TRUNCATE TABLE silver.crm_prd_info;
    RAISE NOTICE '>> Inserting data Into: silver.crm_prd_info';

    INSERT INTO silver.crm_prd_info(
        prd_id,
        cat_id,
        prd_key,
        prd_nm,
        prd_cost,
        prd_line,
        prd_start_dt,
        prd_end_dt
    )
    SELECT
        prd_id,
        REPLACE(substring(prd_key,1,5),'-','_') as cat_id,   --Extract category ID
        SUBSTRING(prd_key,7,LENGTH(prd_key)) AS prd_key,     --Extract product key
        prd_nm, 
        COALESCE(prd_cost,0) AS prd_cost,
        CASE UPPER(TRIM(prd_line))
            WHEN 'M' THEN 'Mountain'
            WHEN 'R' THEN 'Road'
            WHEN 'S' THEN 'Other Sales'
            WHEN 'T' THEN 'Touring'
            ELSE 'n/a'
        END AS prd_line,                --Map product line codes to descriptive values(Data Normalization)
        prd_start_dt,
        (LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt) - INTERVAL
        '1 day'):: DATE as prd_end_dt    --Calculate end date as one day before the next start date
    FROM bronze.crm_prd_info;

    v_duration := clock_timestamp() - v_start_time;
    RAISE NOTICE 'Load Duration: %', v_duration;
    RAISE NOTICE '-------------------';

    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table : silver.crm_sales_details';
    TRUNCATE TABLE silver.crm_sales_details;
    RAISE NOTICE '>> Inserting data Into: silver.crm_sales_details';

    INSERT INTO silver.crm_sales_details(
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        sls_order_dt,
        sls_ship_dt,
        sls_due_dt,
        sls_sales,
        sls_quantity,
        sls_price
    )
    SELECT
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        CASE
            WHEN sls_order_dt <= 0 OR length(sls_order_dt::TEXT) != 8 THEN NULL     --handling Invalid Data and type casting
            ELSE sls_order_dt::TEXT::DATE
        END sls_order_dt,
        CASE
            WHEN sls_ship_dt <= 0 OR length(sls_ship_dt::TEXT) != 8 THEN NULL
            ELSE sls_ship_dt::TEXT::DATE
        END sls_ship_dt,
        CASE
            WHEN sls_due_dt <= 0 OR length(sls_due_dt::TEXT) != 8 THEN NULL
            ELSE sls_due_dt::TEXT::DATE
        END sls_due_dt,
        CASE
            WHEN sls_sales IS NULL OR sls_sales <=0 OR sls_sales != sls_quantity * ABS(sls_price)
                THEN sls_quantity * ABS(sls_price)
            ELSE sls_sales
        END sls_sales,
        sls_quantity,
        CASE
            WHEN sls_price IS NULL OR sls_price <=0
                THEN sls_sales / NULLIF(sls_quantity,0)
            ELSE sls_price
        END sls_price
    FROM bronze.crm_sales_details;

    v_duration := clock_timestamp() - v_start_time;
    RAISE NOTICE 'Load Duration: %', v_duration;
    RAISE NOTICE '-------------------';

    RAISE NOTICE '-------------------------------------------------';
    RAISE NOTICE 'Loading ERP Tables';
    RAISE NOTICE '-------------------------------------------------';

    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: silver.erp_cust_az12';
    TRUNCATE TABLE silver.erp_cust_az12;
    RAISE NOTICE '>> Inserting data Into: silver.erp_cust_az12';

    INSERT INTO silver.erp_cust_az12
    (
        cid,
        bdate,
        gen
    )
    SELECT
        CASE
            WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4,LENGTH(cid)) --Remove 'NAS' prefix if present
            ELSE cid
        END cid,
        CASE
            WHEN bdate > CURRENT_DATE THEN NULL
            ELSE bdate
        END AS bdate,    --Set future birthdates to NULL
        CASE 
        WHEN UPPER(TRIM(gen)) IN ('F','FEMALE') THEN 'Female'
        WHEN UPPER(TRIM(gen)) IN ('M','MALE') THEN 'Male'
        ELSE 'n/a'
    END AS gen          --Normalize gender values and handle unknown cases
    FROM bronze.erp_cust_az12;

    v_duration := clock_timestamp() - v_start_time;
    RAISE NOTICE 'Load Duration: %', v_duration;
    RAISE NOTICE '-------------------';

    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table : silver.erp_loc_a101';
    TRUNCATE TABLE silver.erp_loc_a101;
    RAISE NOTICE '>> Inserting data Into: silver.erp_loc_a101';

    INSERT INTO silver.erp_loc_a101
    (
        cid,
        cntry
    )
    SELECT
        REPLACE(cid,'-','') cid,  --Handled invalid values
        CASE
            WHEN UPPER(TRIM(cntry)) = 'DE' THEN 'Germany'
            WHEN UPPER(TRIM(cntry)) IN ('US','USA') THEN 'United States'
            WHEN UPPER(TRIM(cntry)) = '' OR cntry IS NULL THEN 'n/a'
            ELSE TRIM(cntry)
        END cntry                --Normalize and handle missing or blank country codes
    FROM bronze.erp_loc_a101;

    v_duration := clock_timestamp() - v_start_time;
    RAISE NOTICE 'Load Duration: %', v_duration;
    RAISE NOTICE '-------------------';

    v_start_time := clock_timestamp();

    RAISE NOTICE '>> Truncating Table : silver.erp_px_cat_g1v2';
    TRUNCATE TABLE silver.erp_px_cat_g1v2;
    RAISE NOTICE '>> Inserting data Into: silver.erp_px_cat_g1v2';

    INSERT INTO silver.erp_px_cat_g1v2(
        id,
        cat,
        subcat,
        maintenance
    )
    SELECT 
        id,
        cat,
        subcat,
        maintenance
    FROM bronze.erp_px_cat_g1v2;

    v_duration := clock_timestamp() - v_start_time;
    RAISE NOTICE 'Load Duration: %', v_duration;
    RAISE NOTICE '-------------------';

    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Silver Layer Loading Completed Successfully';
    RAISE NOTICE '=================================================';
 
v_duration := clock_timestamp()-batch_start_time;

RAISE NOTICE '=================================================';
RAISE NOTICE 'Total Silver Load Duration: %', v_duration;
RAISE NOTICE '=================================================';

EXCEPTION 
    WHEN OTHERS THEN
        RAISE NOTICE '==========================================';
        RAISE NOTICE 'ERROR OCCURRED DURING LOADING SILVER LAYER';
        RAISE WARNING 'Error Message: %',SQLERRM;
        RAISE WARNING 'SQLSTATE: %', SQLSTATE;
        RAISE NOTICE '==========================================';
        RAISE;
END $$;

CALL silver.load_silver();
