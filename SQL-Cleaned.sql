-- =====================================================-- =====================================================
USE retail_inventory_project;
SET SQL_SAFE_UPDATES = 0;

-- 1. BACKUP (keeps your raw data safe)
-- DROP TABLE IF EXISTS retail_inventory_raw3_backup;
CREATE TABLE retail_inventory_raw3_backup AS SELECT * FROM retail_inventory_raw3;

-- 2. TRIM ALL TEXT COLUMNS (also removes hidden \r in the last column)
UPDATE retail_inventory_raw3
SET `Date`                     = TRIM(`Date`),
    `Store ID`                 = TRIM(`Store ID`),
    `Product ID`               = TRIM(`Product ID`),
    Category                   = TRIM(Category),
    Region                     = TRIM(Region),
    `Inventory Level`          = TRIM(`Inventory Level`),
    `Units Sold`               = TRIM(`Units Sold`),
    `Units Ordered`            = TRIM(`Units Ordered`),
    `Demand Forecast`          = TRIM(`Demand Forecast`),
    Price                      = TRIM(Price),
    Discount                   = TRIM(Discount),
    `Weather Condition`        = TRIM(`Weather Condition`),
    `Holiday/Promotion`        = TRIM(`Holiday/Promotion`),
    `Competitor Pricing`       = TRIM(`Competitor Pricing`),
    Seasonality                = TRIM(Seasonality),
    `Supplier ID`              = TRIM(`Supplier ID`),
    `Lead Time (Days)`         = TRIM(`Lead Time (Days)`),
    `Supplier Reliability (%)` = TRIM(REPLACE(`Supplier Reliability (%)`, '\r', ''));

-- 3. DATE: two formats -> 'YYYY-MM-DD' (then converted to DATE in step 5)
UPDATE retail_inventory_raw3
SET `Date` = DATE_FORMAT(
        CASE WHEN `Date` LIKE '%/%' THEN STR_TO_DATE(`Date`, '%m/%d/%Y')   -- 03/17/2022
             ELSE STR_TO_DATE(`Date`, '%d-%m-%y')                          -- 06-04-22
        END, '%Y-%m-%d');

-- 4. STANDARDIZE TEXT VALUES
UPDATE retail_inventory_raw3
SET `Store ID`   = REPLACE(UPPER(`Store ID`), 'STORE-', 'S'),
    `Product ID` = UPPER(`Product ID`),
    `Supplier ID`= UPPER(`Supplier ID`),
    Region       = CONCAT(UPPER(LEFT(Region,1)), LOWER(SUBSTRING(Region,2))),
    Seasonality  = CONCAT(UPPER(LEFT(Seasonality,1)), LOWER(SUBSTRING(Seasonality,2))),
    Price        = REPLACE(Price, '$', '');

UPDATE retail_inventory_raw3
SET Category = CASE LOWER(Category)
        WHEN 'electronics' THEN 'Electronics' WHEN 'electronic' THEN 'Electronics'
        WHEN 'furniture'   THEN 'Furniture'   WHEN 'furnitures' THEN 'Furniture'
        WHEN 'toys'        THEN 'Toys'        WHEN 'toy'        THEN 'Toys'
        WHEN 'clothing'    THEN 'Clothing'    WHEN 'cloths'     THEN 'Clothing'
        WHEN 'groceries'   THEN 'Groceries'   WHEN 'grocerries' THEN 'Groceries'
        ELSE 'Unknown' END;

UPDATE retail_inventory_raw3
SET `Weather Condition` = CASE WHEN `Weather Condition` = '' OR `Weather Condition` IS NULL
        THEN 'Unknown'
        ELSE CONCAT(UPPER(LEFT(`Weather Condition`,1)), LOWER(SUBSTRING(`Weather Condition`,2))) END;

UPDATE retail_inventory_raw3
SET `Holiday/Promotion` = CASE LOWER(`Holiday/Promotion`)
        WHEN 'yes' THEN '1' WHEN '1' THEN '1'
        WHEN 'no'  THEN '0' WHEN '0' THEN '0'
        ELSE NULL END;

-- Blank text -> NULL (needed before converting to numbers)
UPDATE retail_inventory_raw3
SET Price                      = NULLIF(Price, ''),
    Discount                   = NULLIF(Discount, ''),
    `Competitor Pricing`       = NULLIF(`Competitor Pricing`, ''),
    `Supplier Reliability (%)` = NULLIF(`Supplier Reliability (%)`, '');

-- 5. CHANGE DATA TYPES
ALTER TABLE retail_inventory_raw3
    MODIFY `Date`                     DATE,
    MODIFY `Store ID`                 VARCHAR(10),
    MODIFY `Product ID`               VARCHAR(10),
    MODIFY Category                   VARCHAR(30),
    MODIFY Region                     VARCHAR(20),
    MODIFY `Inventory Level`          INT,
    MODIFY `Units Sold`               INT,
    MODIFY `Units Ordered`            INT,
    MODIFY `Demand Forecast`          DECIMAL(10,2),
    MODIFY Price                      DECIMAL(10,2),
    MODIFY Discount                   INT,
    MODIFY `Weather Condition`        VARCHAR(20),
    MODIFY `Holiday/Promotion`        TINYINT,
    MODIFY `Competitor Pricing`       DECIMAL(10,2),
    MODIFY Seasonality                VARCHAR(20),
    MODIFY `Supplier ID`              VARCHAR(10),
    MODIFY `Lead Time (Days)`         INT,
    MODIFY `Supplier Reliability (%)` DECIMAL(5,2);

-- 6. FILL MISSING VALUES (now that columns are numeric)
UPDATE retail_inventory_raw3 t
JOIN (SELECT `Product ID` pid, ROUND(AVG(Price),2) v
      FROM retail_inventory_raw3 WHERE Price IS NOT NULL GROUP BY `Product ID`) a
  ON t.`Product ID` = a.pid
SET t.Price = a.v WHERE t.Price IS NULL;

UPDATE retail_inventory_raw3 t
JOIN (SELECT `Product ID` pid, ROUND(AVG(`Competitor Pricing`),2) v
      FROM retail_inventory_raw3 WHERE `Competitor Pricing` IS NOT NULL GROUP BY `Product ID`) a
  ON t.`Product ID` = a.pid
SET t.`Competitor Pricing` = a.v WHERE t.`Competitor Pricing` IS NULL;

UPDATE retail_inventory_raw3 t
JOIN (SELECT `Product ID` pid, MAX(`Supplier Reliability (%)`) v
      FROM retail_inventory_raw3 WHERE `Supplier Reliability (%)` IS NOT NULL GROUP BY `Product ID`) a
  ON t.`Product ID` = a.pid
SET t.`Supplier Reliability (%)` = a.v WHERE t.`Supplier Reliability (%)` IS NULL;

UPDATE retail_inventory_raw3 SET Discount = 0 WHERE Discount IS NULL;

-- 7. VALIDATION
DESCRIBE retail_inventory_raw3;

SELECT COUNT(*) AS total_rows,
       SUM(`Date` IS NULL)                      AS null_date,
       SUM(Price IS NULL)                       AS null_price,
       SUM(`Competitor Pricing` IS NULL)        AS null_comp_price,
       SUM(`Supplier Reliability (%)` IS NULL)  AS null_reliability,
       SUM(Category = 'Unknown')                AS unknown_category
FROM retail_inventory_raw3;

SELECT DISTINCT `Store ID` FROM retail_inventory_raw3;
SELECT DISTINCT Category   FROM retail_inventory_raw3;
SELECT DISTINCT Region     FROM retail_inventory_raw3;
SELECT MIN(`Date`), MAX(`Date`) FROM retail_inventory_raw3;

SET SQL_SAFE_UPDATES = 1;

SELECT COUNT(*) FROM retail_inventory_clean;


USE retail_inventory_project;
SET SQL_SAFE_UPDATES = 0;

-- Remove the old duplicate clean table
DROP TABLE IF EXISTS retail_inventory_clean;

-- Rename (step 2)
RENAME TABLE retail_inventory_raw3 TO retail_inventory_clean;

-- Primary key (step 3)
ALTER TABLE retail_inventory_clean
    ADD COLUMN record_id INT AUTO_INCREMENT PRIMARY KEY FIRST;

-- Indexes (step 4)
CREATE INDEX idx_date     ON retail_inventory_clean (sale_date);
CREATE INDEX idx_store    ON retail_inventory_clean (store_id);
CREATE INDEX idx_product  ON retail_inventory_clean (product_id);
CREATE INDEX idx_supplier ON retail_inventory_clean (supplier_id);


-- Quick confirmation
DESCRIBE retail_inventory_clean;
SELECT COUNT(*) AS total_rows FROM retail_inventory_clean;

SET SQL_SAFE_UPDATES = 1;

USE retail_inventory_project;

SHOW TABLES;
DESCRIBE retail_inventory_clean;
SELECT COUNT(*) FROM retail_inventory_clean;


USE retail_inventory_project;

SHOW INDEX FROM retail_inventory_clean;

SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT store_id)   AS stores,
       COUNT(DISTINCT product_id) AS products,
       MIN(sale_date) AS first_date,
       MAX(sale_date) AS last_date,
       SUM(price IS NULL) AS null_price,
       SUM(category = 'Unknown') AS unknown_category
FROM retail_inventory_clean;


SELECT * FROM retail_inventory_clean;





