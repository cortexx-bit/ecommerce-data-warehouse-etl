-- Analysis of Top-Selling Products
-- This script retrieves insights about top-selling products from the data warehouse

-- 1. Top-selling products by quantity sold
SELECT 
    p.Product_Name,
    SUM(fs.Quantity_Sold) as Total_Quantity_Sold,
    SUM(fs.Sales_Revenue) as Total_Revenue,
    COUNT(DISTINCT fs.Order_ID) as Number_Of_Orders
FROM Fact_Sales fs
JOIN Dim_Product p ON fs.Product_ID = p.Product_ID
GROUP BY p.Product_Name
ORDER BY Total_Quantity_Sold DESC
LIMIT 10;

-- 2. Top-selling products by revenue
SELECT 
    p.Product_Name,
    SUM(fs.Sales_Revenue) as Total_Revenue,
    SUM(fs.Quantity_Sold) as Total_Quantity_Sold,
    COUNT(DISTINCT fs.Order_ID) as Number_Of_Orders
FROM Fact_Sales fs
JOIN Dim_Product p ON fs.Product_ID = p.Product_ID
GROUP BY p.Product_Name
ORDER BY Total_Revenue DESC
LIMIT 10;

-- 3. Top-selling products with average rating
SELECT 
    p.Product_Name,
    SUM(fs.Quantity_Sold) as Total_Quantity_Sold,
    SUM(fs.Sales_Revenue) as Total_Revenue,
    ROUND(AVG(ff.Rating)::numeric, 2) as Average_Rating,
    COUNT(DISTINCT ff.Feedback_ID) as Number_Of_Reviews
FROM Fact_Sales fs
JOIN Dim_Product p ON fs.Product_ID = p.Product_ID
LEFT JOIN Fact_Feedback ff ON p.Product_ID = ff.Product_ID
GROUP BY p.Product_Name
ORDER BY Total_Quantity_Sold DESC
LIMIT 10;

-- 4. Top-selling products with inventory status
SELECT 
    p.Product_Name,
    SUM(fs.Quantity_Sold) as Total_Quantity_Sold,
    SUM(fs.Sales_Revenue) as Total_Revenue,
    fi.Stock_Level as Current_Stock,
    fi.Reorder_Point,
    CASE 
        WHEN fi.Stock_Level <= fi.Reorder_Point THEN 'Low Stock'
        ELSE 'In Stock'
    END as Stock_Status
FROM Fact_Sales fs
JOIN Dim_Product p ON fs.Product_ID = p.Product_ID
LEFT JOIN Fact_Inventory fi ON p.Product_ID = fi.Product_ID
    AND fi.Time_ID = (
        SELECT MAX(Time_ID) 
        FROM Fact_Inventory
    )
GROUP BY p.Product_Name, fi.Stock_Level, fi.Reorder_Point
ORDER BY Total_Quantity_Sold DESC
LIMIT 10;

-- 5. Monthly sales trend for top 5 products
WITH Top_Products AS (
    SELECT 
        p.Product_Name,
        SUM(fs.Quantity_Sold) as Total_Quantity_Sold
    FROM Fact_Sales fs
    JOIN Dim_Product p ON fs.Product_ID = p.Product_ID
    GROUP BY p.Product_Name
    ORDER BY Total_Quantity_Sold DESC
    LIMIT 5
)
SELECT 
    tp.Product_Name,
    t.Year,
    t.Month,
    SUM(fs.Quantity_Sold) as Monthly_Quantity,
    SUM(fs.Sales_Revenue) as Monthly_Revenue
FROM Top_Products tp
JOIN Fact_Sales fs ON tp.Product_Name = (
    SELECT Product_Name 
    FROM Dim_Product 
    WHERE Product_ID = fs.Product_ID
)
JOIN Dim_Time t ON fs.Time_ID = t.Time_ID
GROUP BY tp.Product_Name, t.Year, t.Month
ORDER BY tp.Product_Name, t.Year, t.Month; 