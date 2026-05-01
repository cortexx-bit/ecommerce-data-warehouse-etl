-- Analysis of Current Stock Levels
-- This script retrieves insights about current inventory status from the inventory data

-- 1. Current stock levels for all products
SELECT 
    p.Product_Name,
    fi.Stock_Level as Current_Stock,
    fi.Reorder_Point,
    CASE 
        WHEN fi.Stock_Level <= fi.Reorder_Point THEN 'Low Stock'
        WHEN fi.Stock_Level <= (fi.Reorder_Point * 1.5) THEN 'Medium Stock'
        ELSE 'High Stock'
    END as Stock_Status
FROM Fact_Inventory fi
JOIN Dim_Product p ON fi.Product_ID = p.Product_ID
WHERE fi.Time_ID = (
    SELECT MAX(Time_ID) 
    FROM Fact_Inventory
)
ORDER BY fi.Stock_Level;

-- 2. Products that need reordering (below reorder point)
SELECT 
    p.Product_Name,
    fi.Stock_Level as Current_Stock,
    fi.Reorder_Point,
    (fi.Reorder_Point - fi.Stock_Level) as Units_Needed
FROM Fact_Inventory fi
JOIN Dim_Product p ON fi.Product_ID = p.Product_ID
WHERE fi.Time_ID = (
    SELECT MAX(Time_ID) 
    FROM Fact_Inventory
)
AND fi.Stock_Level <= fi.Reorder_Point
ORDER BY (fi.Reorder_Point - fi.Stock_Level) DESC;

-- 3. Stock levels with sales data
SELECT 
    p.Product_Name,
    fi.Stock_Level as Current_Stock,
    fi.Reorder_Point,
    SUM(fs.Quantity_Sold) as Total_Quantity_Sold,
    ROUND(SUM(fs.Quantity_Sold)::numeric / NULLIF(fi.Stock_Level, 0), 2) as Stock_Turnover_Ratio
FROM Fact_Inventory fi
JOIN Dim_Product p ON fi.Product_ID = p.Product_ID
LEFT JOIN Fact_Sales fs ON p.Product_ID = fs.Product_ID
WHERE fi.Time_ID = (
    SELECT MAX(Time_ID) 
    FROM Fact_Inventory
)
GROUP BY p.Product_Name, fi.Stock_Level, fi.Reorder_Point
ORDER BY Stock_Turnover_Ratio DESC NULLS LAST;

-- 4. Stock levels with customer ratings
SELECT 
    p.Product_Name,
    fi.Stock_Level as Current_Stock,
    fi.Reorder_Point,
    ROUND(AVG(ff.Rating)::numeric, 2) as Average_Rating,
    COUNT(ff.Feedback_ID) as Number_Of_Reviews
FROM Fact_Inventory fi
JOIN Dim_Product p ON fi.Product_ID = p.Product_ID
LEFT JOIN Fact_Feedback ff ON p.Product_ID = ff.Product_ID
WHERE fi.Time_ID = (
    SELECT MAX(Time_ID) 
    FROM Fact_Inventory
)
GROUP BY p.Product_Name, fi.Stock_Level, fi.Reorder_Point
ORDER BY Average_Rating DESC NULLS LAST;

-- 5. Stock level trends (last 3 snapshots)
WITH Ranked_Inventory AS (
    SELECT 
        p.Product_Name,
        fi.Stock_Level,
        fi.Reorder_Point,
        fi.Time_ID,
        ROW_NUMBER() OVER (PARTITION BY p.Product_Name ORDER BY fi.Time_ID DESC) as rn
    FROM Fact_Inventory fi
    JOIN Dim_Product p ON fi.Product_ID = p.Product_ID
)
SELECT 
    Product_Name,
    MAX(CASE WHEN rn = 1 THEN Stock_Level END) as Current_Stock,
    MAX(CASE WHEN rn = 2 THEN Stock_Level END) as Previous_Stock,
    MAX(CASE WHEN rn = 3 THEN Stock_Level END) as Two_Previous_Stock,
    MAX(Reorder_Point) as Reorder_Point,
    CASE 
        WHEN MAX(CASE WHEN rn = 1 THEN Stock_Level END) < 
             MAX(CASE WHEN rn = 2 THEN Stock_Level END) THEN 'Decreasing'
        WHEN MAX(CASE WHEN rn = 1 THEN Stock_Level END) > 
             MAX(CASE WHEN rn = 2 THEN Stock_Level END) THEN 'Increasing'
        ELSE 'Stable'
    END as Stock_Trend
FROM Ranked_Inventory
GROUP BY Product_Name
ORDER BY Product_Name;

-- 6. Stock levels with sales velocity
SELECT 
    p.Product_Name,
    fi.Stock_Level as Current_Stock,
    fi.Reorder_Point,
    SUM(fs.Quantity_Sold) as Total_Quantity_Sold,
    COUNT(DISTINCT t.Month) as Number_Of_Months,
    ROUND(SUM(fs.Quantity_Sold)::numeric / NULLIF(COUNT(DISTINCT t.Month), 0), 2) as Monthly_Sales_Average,
    ROUND(fi.Stock_Level::numeric / NULLIF(SUM(fs.Quantity_Sold)::numeric / NULLIF(COUNT(DISTINCT t.Month), 0), 0), 2) as Months_Of_Stock
FROM Fact_Inventory fi
JOIN Dim_Product p ON fi.Product_ID = p.Product_ID
LEFT JOIN Fact_Sales fs ON p.Product_ID = fs.Product_ID
LEFT JOIN Dim_Time t ON fs.Time_ID = t.Time_ID
WHERE fi.Time_ID = (
    SELECT MAX(Time_ID) 
    FROM Fact_Inventory
)
GROUP BY p.Product_Name, fi.Stock_Level, fi.Reorder_Point
ORDER BY Months_Of_Stock DESC NULLS LAST;

-- 7. Stock levels with seasonal analysis
SELECT 
    p.Product_Name,
    fi.Stock_Level as Current_Stock,
    fi.Reorder_Point,
    t.Quarter,
    SUM(fs.Quantity_Sold) as Quarterly_Sales
FROM Fact_Inventory fi
JOIN Dim_Product p ON fi.Product_ID = p.Product_ID
LEFT JOIN Fact_Sales fs ON p.Product_ID = fs.Product_ID
LEFT JOIN Dim_Time t ON fs.Time_ID = t.Time_ID
WHERE fi.Time_ID = (
    SELECT MAX(Time_ID) 
    FROM Fact_Inventory
)
GROUP BY p.Product_Name, fi.Stock_Level, fi.Reorder_Point, t.Quarter
ORDER BY p.Product_Name, t.Quarter;

-- 8. Critical inventory items (low stock with high sales)
SELECT 
    p.Product_Name,
    fi.Stock_Level as Current_Stock,
    fi.Reorder_Point,
    SUM(fs.Quantity_Sold) as Total_Quantity_Sold,
    SUM(fs.Sales_Revenue) as Total_Revenue,
    CASE 
        WHEN fi.Stock_Level <= fi.Reorder_Point AND SUM(fs.Quantity_Sold) > 100 THEN 'Critical'
        WHEN fi.Stock_Level <= (fi.Reorder_Point * 1.5) AND SUM(fs.Quantity_Sold) > 100 THEN 'Warning'
        ELSE 'Normal'
    END as Inventory_Status
FROM Fact_Inventory fi
JOIN Dim_Product p ON fi.Product_ID = p.Product_ID
LEFT JOIN Fact_Sales fs ON p.Product_ID = fs.Product_ID
WHERE fi.Time_ID = (
    SELECT MAX(Time_ID) 
    FROM Fact_Inventory
)
GROUP BY p.Product_Name, fi.Stock_Level, fi.Reorder_Point
ORDER BY Inventory_Status, Total_Quantity_Sold DESC; 