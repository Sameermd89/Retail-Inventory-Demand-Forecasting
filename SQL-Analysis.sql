
-- =========================================================
-- RETAIL INVENTORY ANALYTICS PROJECT
-- Database: retail_inventory_project
-- Table: retail_inventory_clean
-- =========================================================

USE retail_inventory_project;


-- =========================================================
-- 1. OVERALL BUSINESS KPIs
-- =========================================================

SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT store_id) AS total_stores,
    COUNT(DISTINCT product_id) AS total_products,
    COUNT(DISTINCT category) AS total_categories,
    SUM(inventory_level) AS total_inventory,
    SUM(units_sold) AS total_units_sold,
    SUM(units_ordered) AS total_units_ordered,
    ROUND(AVG(price), 2) AS average_price,
    ROUND(AVG(demand_forecast), 2) AS average_demand_forecast,
    ROUND(AVG(lead_time_days), 2) AS average_lead_time
FROM retail_inventory_clean;


-- =========================================================
-- 2. DATA QUALITY VALIDATION
-- =========================================================

SELECT
    COUNT(*) AS total_records,
    SUM(sale_date IS NULL) AS missing_dates,
    SUM(store_id IS NULL OR TRIM(store_id) = '') AS missing_stores,
    SUM(product_id IS NULL OR TRIM(product_id) = '') AS missing_products,
    SUM(category IS NULL OR category = 'Unknown') AS missing_or_unknown_category,
    SUM(region IS NULL OR TRIM(region) = '') AS missing_regions,
    SUM(inventory_level IS NULL) AS missing_inventory,
    SUM(units_sold IS NULL) AS missing_units_sold,
    SUM(units_ordered IS NULL) AS missing_units_ordered,
    SUM(demand_forecast IS NULL) AS missing_forecasts,
    SUM(price IS NULL) AS missing_prices,
    SUM(competitor_pricing IS NULL) AS missing_competitor_prices,
    SUM(supplier_reliability IS NULL) AS missing_supplier_reliability
FROM retail_inventory_clean;


-- =========================================================
-- 3. DUPLICATE BUSINESS RECORD CHECK
-- Excludes record_id because it is unique by design.
-- =========================================================

SELECT
    sale_date,
    store_id,
    product_id,
    COUNT(*) AS duplicate_count
FROM retail_inventory_clean
GROUP BY sale_date, store_id, product_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;


-- =========================================================
-- 4. SALES PERFORMANCE BY CATEGORY
-- =========================================================

SELECT
    category,
    SUM(units_sold) AS total_units_sold,
    ROUND(AVG(units_sold), 2) AS average_units_sold,
    ROUND(AVG(price), 2) AS average_price,
    ROUND(AVG(demand_forecast), 2) AS average_demand_forecast
FROM retail_inventory_clean
GROUP BY category
ORDER BY total_units_sold DESC;


-- =========================================================
-- 5. SALES PERFORMANCE BY REGION
-- =========================================================

SELECT
    region,
    SUM(units_sold) AS total_units_sold,
    SUM(units_ordered) AS total_units_ordered,
    ROUND(AVG(inventory_level), 2) AS average_inventory,
    ROUND(AVG(demand_forecast), 2) AS average_demand
FROM retail_inventory_clean
GROUP BY region
ORDER BY total_units_sold DESC;


-- =========================================================
-- 6. SALES PERFORMANCE BY SEASONALITY
-- =========================================================

SELECT
    seasonality,
    SUM(units_sold) AS total_units_sold,
    ROUND(AVG(units_sold), 2) AS average_units_sold,
    ROUND(AVG(demand_forecast), 2) AS average_demand_forecast
FROM retail_inventory_clean
GROUP BY seasonality
ORDER BY total_units_sold DESC;


-- =========================================================
-- 7. TOP 10 PRODUCTS BY SALES
-- =========================================================

SELECT
    product_id,
    category,
    SUM(units_sold) AS total_units_sold,
    SUM(units_ordered) AS total_units_ordered,
    ROUND(AVG(price), 2) AS average_price,
    ROUND(AVG(inventory_level), 2) AS average_inventory
FROM retail_inventory_clean
GROUP BY product_id, category
ORDER BY total_units_sold DESC
LIMIT 10;


-- =========================================================
-- 8. STORE PERFORMANCE
-- =========================================================

SELECT
    store_id,
    region,
    SUM(units_sold) AS total_units_sold,
    SUM(units_ordered) AS total_units_ordered,
    ROUND(AVG(inventory_level), 2) AS average_inventory,
    ROUND(AVG(demand_forecast), 2) AS average_demand
FROM retail_inventory_clean
GROUP BY store_id, region
ORDER BY total_units_sold DESC;


-- =========================================================
-- 9. INVENTORY RISK SUMMARY
-- Preliminary rule: inventory below forecast = low stock.
-- Assumes inventory and forecast use comparable units.
-- =========================================================

SELECT
    CASE
        WHEN inventory_level < demand_forecast
            THEN 'Low Stock Risk'
        ELSE 'Sufficient Stock'
    END AS stock_status,
    COUNT(*) AS total_records,
    ROUND(
        100.0 * COUNT(*) /
        (SELECT COUNT(*) FROM retail_inventory_clean),
        2
    ) AS percentage_of_records
FROM retail_inventory_clean
WHERE inventory_level IS NOT NULL
  AND demand_forecast IS NOT NULL
GROUP BY stock_status;


-- =========================================================
-- 10. LOW STOCK RISK BY REGION
-- =========================================================

SELECT
    region,
    COUNT(*) AS total_records,
    SUM(inventory_level < demand_forecast) AS low_stock_records,
    ROUND(
        100.0 * SUM(inventory_level < demand_forecast) /
        COUNT(*),
        2
    ) AS low_stock_percentage
FROM retail_inventory_clean
WHERE inventory_level IS NOT NULL
  AND demand_forecast IS NOT NULL
GROUP BY region
ORDER BY low_stock_percentage DESC;


-- =========================================================
-- 11. LOW STOCK RISK BY CATEGORY
-- =========================================================

SELECT
    category,
    COUNT(*) AS total_records,
    SUM(inventory_level < demand_forecast) AS low_stock_records,
    ROUND(
        100.0 * SUM(inventory_level < demand_forecast) /
        COUNT(*),
        2
    ) AS low_stock_percentage
FROM retail_inventory_clean
WHERE inventory_level IS NOT NULL
  AND demand_forecast IS NOT NULL
GROUP BY category
ORDER BY low_stock_records DESC;


-- =========================================================
-- 12. PRODUCT-LEVEL INVENTORY SHORTFALL
-- Aggregates across records; not necessarily current stock.
-- =========================================================

SELECT
    product_id,
    category,
    SUM(units_sold) AS total_units_sold,
    ROUND(SUM(demand_forecast), 2) AS total_forecast,
    SUM(inventory_level) AS summed_inventory,
    ROUND(
        SUM(demand_forecast) - SUM(inventory_level), 2
    ) AS aggregate_shortfall
FROM retail_inventory_clean
GROUP BY product_id, category
ORDER BY aggregate_shortfall DESC
LIMIT 20;


-- =========================================================
-- 13. REORDER PRIORITY
-- Illustrative screening rule, not a final reorder quantity.
-- Seven-day lead-time threshold is an assumption.
-- =========================================================

SELECT
    record_id,
    sale_date,
    store_id,
    product_id,
    category,
    region,
    inventory_level,
    demand_forecast,
    lead_time_days,
    supplier_reliability,
    CASE
        WHEN inventory_level < demand_forecast
             AND lead_time_days >= 7
            THEN 'High Priority'
        WHEN inventory_level < demand_forecast
            THEN 'Medium Priority'
        ELSE 'Sufficient Stock'
    END AS reorder_priority
FROM retail_inventory_clean
WHERE inventory_level IS NOT NULL
  AND demand_forecast IS NOT NULL
ORDER BY
    CASE
        WHEN inventory_level < demand_forecast
             AND lead_time_days >= 7 THEN 1
        WHEN inventory_level < demand_forecast THEN 2
        ELSE 3
    END,
    (demand_forecast - inventory_level) DESC;


-- =========================================================
-- 14. REORDER PRIORITY SUMMARY
-- =========================================================

SELECT
    CASE
        WHEN inventory_level < demand_forecast
             AND lead_time_days >= 7
            THEN 'High Priority'
        WHEN inventory_level < demand_forecast
            THEN 'Medium Priority'
        ELSE 'Sufficient Stock'
    END AS reorder_priority,
    COUNT(*) AS total_records
FROM retail_inventory_clean
WHERE inventory_level IS NOT NULL
  AND demand_forecast IS NOT NULL
GROUP BY reorder_priority
ORDER BY total_records DESC;


-- =========================================================
-- 15. SUPPLIER PERFORMANCE
-- =========================================================

SELECT
    supplier_id,
    COUNT(*) AS total_records,
    ROUND(AVG(lead_time_days), 2) AS average_lead_time,
    ROUND(AVG(supplier_reliability), 2) AS average_reliability,
    SUM(units_ordered) AS total_units_ordered
FROM retail_inventory_clean
GROUP BY supplier_id
ORDER BY average_reliability DESC;


-- =========================================================
-- 16. MONTHLY SALES AND FORECAST TREND
-- =========================================================

SELECT
    DATE_FORMAT(sale_date, '%Y-%m') AS sales_month,
    SUM(units_sold) AS total_units_sold,
    SUM(units_ordered) AS total_units_ordered,
    ROUND(AVG(demand_forecast), 2) AS average_demand_forecast,
    ROUND(AVG(inventory_level), 2) AS average_inventory
FROM retail_inventory_clean
WHERE sale_date IS NOT NULL
GROUP BY DATE_FORMAT(sale_date, '%Y-%m')
ORDER BY sales_month;


-- =========================================================
-- 17. ACTUAL SALES VS FORECAST BY CATEGORY
-- =========================================================

SELECT
    category,
    SUM(units_sold) AS actual_units_sold,
    ROUND(SUM(demand_forecast), 2) AS total_forecast,
    ROUND(
        SUM(units_sold) - SUM(demand_forecast), 2
    ) AS sales_forecast_difference
FROM retail_inventory_clean
GROUP BY category
ORDER BY sales_forecast_difference;


-- =========================================================
-- 18. DISCOUNT ANALYSIS
-- =========================================================

SELECT
    discount,
    COUNT(*) AS total_records,
    SUM(units_sold) AS total_units_sold,
    ROUND(AVG(price), 2) AS average_price
FROM retail_inventory_clean
GROUP BY discount
ORDER BY discount;


-- =========================================================
-- 19. WEATHER-BASED SALES ANALYSIS
-- =========================================================

SELECT
    weather_condition,
    COUNT(*) AS total_records,
    SUM(units_sold) AS total_units_sold,
    ROUND(AVG(units_sold), 2) AS average_units_sold,
    ROUND(AVG(demand_forecast), 2) AS average_forecast
FROM retail_inventory_clean
GROUP BY weather_condition
ORDER BY total_units_sold DESC;


-- =========================================================
-- 20. FINAL DATASET VALIDATION
-- =========================================================

SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT record_id) AS unique_record_ids,
    COUNT(DISTINCT store_id) AS total_stores,
    COUNT(DISTINCT product_id) AS total_products,
    MIN(sale_date) AS first_date,
    MAX(sale_date) AS last_date,
    SUM(price IS NULL) AS missing_prices,
    SUM(category = 'Unknown') AS unknown_categories
FROM retail_inventory_clean;
