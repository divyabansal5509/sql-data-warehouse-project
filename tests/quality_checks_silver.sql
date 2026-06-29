/*
===============================================================================
Quality Checks
===============================================================================
Script Purpose:
    This script performs various quality checks for data consistency, accuracy
    and standardization across the 'silver' schemas. It includes checks for:
        - Null or duplicate values
        - Unwanted spaces in string fields
        - Data standardization and consistency
        - Invalid date ranges and orders
        - Data consistency between related fields
    
Usage Notes:
    - Run these checks data loading Silver Layer.
    - Investigate and resolve any discrepancies found during the checks.
===============================================================================
*/

--===================================================
--CLeaning bronze.crm_cust_info
--===================================================


SELECT * FROM bronze.crm_cust_info LIMIT 7;

--Check for Nulls and Duplicates in Primary Key
--Expectations : NO RESULT

SELECT 
    cst_id,
    COUNT(*)
FROM bronze.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;  
  

--Check for unwanted spaces
--Expectations : NO RESULT
SELECT
    cst_firstname
FROM bronze.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);
--WHERE cst_lastname != TRIM(cst_lastname);

--Data Standardization & Consistency
SELECT 
    DISTINCT(cst_gndr)
    FROM bronze.crm_cust_info;

SELECT 
    DISTINCT(cst_marital_status)
    FROM bronze.crm_cust_info;

--===================================================
--Cleaning from bronze.crm_prd_info
--===================================================

SELECT * FROM silver.crm_prd_info LIMIT 7;

--Check for Nulls and Duplicates in Primary Key
--Expectations : NO RESULT

SELECT prd_id,
    COUNT(*) FROM bronze.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 or prd_id IS NULL ;

--Prd key have category id in it's part
SELECT
    prd_id,
    prd_key,
    REPLACE(substring(prd_key,1,5),'-','_') as cat_id,
    SUBSTRING(prd_key,7,LENGTH(prd_key)) AS prd_key,
    prd_nm, 
    COALESCE(prd_cost,0) AS prd_cost,
    CASE UPPER(TRIM(prd_line))
        WHEN 'M' THEN 'Mountain'
        WHEN 'R' THEN 'Road'
        WHEN 'S' THEN 'Other Sales'
        WHEN 'T' THEN 'Touring'
        ELSE 'n/a'
    END AS prd_line,
    prd_start_dt,
    (LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt) - INTERVAL
     '1 day'):: DATE as prd_end_dt    
FROM bronze.crm_prd_info;
--WHERE SUBSTRING(prd_key,7,LENGTH(prd_key)) IN
--(SELECT sls_prd_key
--FROM bronze.crm_sales_details);
--WHERE REPLACE(substring(prd_key,1,5),'-','_') 
--NOT IN    --filters out unmatched data after applying transformation
--(SELECT DISTINCT id
--FROM bronze.erp_px_cat_g1v2);

SELECT DISTINCT id
FROM bronze.erp_px_cat_g1v2;

SELECT sls_prd_key 
FROM bronze.crm_sales_details;

--Check for unwanted spaces
--Expectations : NO RESULT
SELECT
    prd_nm
FROM bronze.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

--Check for Nulls and Negative Numbers
--Expectation: No Results
SELECT prd_cost
FROM bronze.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

--Data Standardization & Consistency
SELECT DISTINCT prd_line
FROM bronze.crm_prd_info;

--Check for invalid dates

SELECT *
FROM bronze.crm_prd_info
WHERE prd_end_dt < prd_start_dt;


--Trying for some columns to get our right new end date
SELECT 
    prd_id,
    prd_key,
    prd_nm,
    prd_start_dt,
    prd_end_dt,
    (lead(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt) - INTERVAL
     '1 day')as prd_end_dt
FROM bronze.crm_prd_info
WHERE prd_key IN('AC-HE-HL-U509-R','AC-HE-HL-U509');

--===================================================
--Cleaning from bronze.crm_sales_details
--===================================================

SELECT * FROM bronze.crm_sales_details LIMIT 10;

--Checking for Unwanted Spaces
SELECT * FROM bronze.crm_sales_details WHERE
sls_ord_num != TRIM(sls_ord_num);

--Checking for Integrity of Columns
SELECT * FROM bronze.crm_sales_details
WHERE sls_prd_key NOT IN (SELECT prd_key FROM silver.crm_prd_info);

SELECT * FROM bronze.crm_sales_details
WHERE sls_cust_id NOT IN (SELECT cst_id FROM silver.crm_cust_info);

--Check for Invalid Dates
--Checking for Outliers by validating the boundaries of the data range
SELECT
NULLIF(sls_order_dt,0) AS sls_order_dt   --Return Null if two given values are equal,otherwise return first expression
FROM bronze.crm_sales_details
WHERE sls_order_dt <= 0 
OR length(sls_order_dt::TEXT) != 8
OR sls_order_dt > 20500101
OR sls_order_dt < 19000101;

SELECT
NULLIF(sls_ship_dt,0) AS sls_ship_dt   --Return Null if two given values are equal,otherwise return first expression
FROM bronze.crm_sales_details
WHERE sls_ship_dt <= 0 
OR length(sls_ship_dt::TEXT) != 8
OR sls_ship_dt > 20500101
OR sls_ship_dt < 19000101;

SELECT
NULLIF(sls_due_dt,0) AS sls_due_dt   --Return Null if two given values are equal,otherwise return first expression
FROM bronze.crm_sales_details
WHERE sls_due_dt <= 0 
OR length(sls_ship_dt::TEXT) != 8
OR sls_due_dt > 20500101
OR sls_due_dt < 19000101;

--Check for Invalid Dates
--Order Date must always be earlier than the shipping Date
SELECT
    sls_order_dt,
    sls_ship_dt,
    sls_due_dt
FROM bronze.crm_sales_details
WHERE sls_due_dt < sls_order_dt OR sls_ship_dt < sls_order_dt;

--Check Data Consistency: BETWEEN sales,quantity and Price
-->> Sales = Quantity*Price
-->> Values must not be NULL,Zero or Negative
--For bad Data Quality we have some rules here:
--1) If Sales is negative or zero, derive it from using Quantity and Price
--2) If Price is zero or Null, calculate it using Sales and Quantity
--3) If Price is negative convert it to a positive value

SELECT DISTINCT
    sls_sales AS old_sls_sales,
    sls_quantity,
    sls_price AS old_sls_price,
    CASE
        WHEN sls_sales IS NULL OR sls_sales <=0 OR sls_sales != sls_quantity * ABS(sls_price)
            THEN sls_quantity * ABS(sls_price)
        ELSE sls_sales
    END sls_sales,
    CASE
        WHEN sls_price IS NULL OR sls_price <=0
            THEN sls_sales / NULLIF(sls_quantity,0)
        ELSE sls_price
    END sls_price
FROM bronze.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL or sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 or sls_price <= 0
ORDER BY sls_sales,sls_quantity,sls_price;


---CLeaned
SELECT
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    CASE
        WHEN sls_order_dt <= 0 OR length(sls_order_dt::TEXT) != 8 THEN NULL
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

--===================================================
--Cleaning from bronze.erp_cust_az12
--===================================================

--Identify Out of Range Dates

SELECT DISTINCT
bdate
FROM bronze.erp_cust_az12
WHERE
bdate < '1925-06-29' OR bdate > CURRENT_DATE;

--Data Standardization & Consistency
SELECT DISTINCT
gen,
CASE 
    WHEN UPPER(TRIM(gen)) IN ('F','FEMALE') THEN 'Female'
    WHEN UPPER(TRIM(gen)) IN ('M','MALE') THEN 'Male'
    ELSE 'n/a'
END AS gen
FROM bronze.erp_cust_az12;

SELECT DISTINCT
gen
FROM silver.erp_cust_az12;

--CLeaned
SELECT
    CASE
        WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4,length(cid))
        ELSE cid
    END cid,
    CASE
        WHEN bdate > CURRENT_DATE THEN NULL
        ELSE bdate
    END AS bdate,
    CASE 
    WHEN UPPER(TRIM(gen)) IN ('F','FEMALE') THEN 'Female'
    WHEN UPPER(TRIM(gen)) IN ('M','MALE') THEN 'Male'
    ELSE 'n/a'
END AS gen
FROM bronze.erp_cust_az12;

--===================================================
--Cleaning from bronze.erp_loc_a101
--===================================================


SELECT
cst_key FROM silver.crm_cust_info;

SELECT DISTINCT 
    cntry,
    CASE
        WHEN UPPER(TRIM(cntry)) = 'DE' THEN 'Germany'
        WHEN UPPER(TRIM(cntry)) IN ('US','USA') THEN 'United States'
        WHEN UPPER(TRIM(cntry)) = '' OR cntry IS NULL THEN 'n/a'
        ELSE TRIM(cntry)
    END cntry
FROM bronze.erp_loc_a101;

--CLeaned
SELECT
    REPLACE(cid,'-','') cid,
    CASE
        WHEN UPPER(TRIM(cntry)) = 'DE' THEN 'Germany'
        WHEN UPPER(TRIM(cntry)) IN ('US','USA') THEN 'United States'
        WHEN UPPER(TRIM(cntry)) = '' OR cntry IS NULL THEN 'n/a'
        ELSE TRIM(cntry)
    END cntry
FROM bronze.erp_loc_a101;

--===================================================
--Cleaning from bronze.erp_px_cat_g1v2
--===================================================

--CHeck for unwanted spaces
SELECT 
    *
FROM bronze.erp_px_cat_g1v2
WHERE cat != TRIM(cat) or subcat != TRIM(subcat) OR maintenance != TRIM(maintenance);

--Data Standardization & Consistency
SELECT DISTINCT
cat
FROM bronze.erp_px_cat_g1v2

--CLeaned
SELECT 
    id,
    cat,
    subcat,
    maintenance
FROM bronze.erp_px_cat_g1v2;
