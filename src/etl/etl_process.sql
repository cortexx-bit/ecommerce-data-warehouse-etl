-- ETL Process for ABC E-Commerce Data Warehouse
-- This script handles the extraction, transformation, and loading of data from various sources
-- into the data warehouse using PostgreSQL

-- Step 1: Create necessary tables for staging data
-- This allows us to load raw data before transformation

-- Staging table for Sales data (extracted from existing Sales_Transactions table)
CREATE TABLE Staging_Sales AS
SELECT 
    Order_ID, 
    Customer_ID, 
    Product_Name, 
    Quantity_Sold, 
    Sales_Revenue, 
    Order_Date
FROM Sales_Transactions;

-- Staging table for Customer Feedback data (using JSONB for better performance)
CREATE TABLE Staging_Feedback_Raw (
    Feedback_Json JSONB
);

-- Load raw JSON data
COPY Staging_Feedback_Raw (Feedback_Json) 
FROM 'path/to/Feedback.json';

-- Extract structured fields from JSON
CREATE TABLE Staging_Feedback AS
SELECT 
    Feedback_Json->>'Customer_ID' AS Customer_ID,
    Feedback_Json->>'Product_ID' AS Product_Name,
    (Feedback_Json->>'Rating')::INTEGER AS Rating,
    Feedback_Json->>'Review_Text' AS Review_Text,
    (Feedback_Json->>'Feedback_Date')::DATE AS Feedback_Date
FROM Staging_Feedback_Raw;

-- Staging table for Inventory data with proper data types
CREATE TABLE Staging_Inventory (
    Product_ID INTEGER,
    Stock_Level INTEGER,
    Reorder_Point INTEGER,
    Snapshot_Date DATE
);

-- Load Inventory data with explicit CSV format
COPY Staging_Inventory (Product_ID, Stock_Level, Reorder_Point, Snapshot_Date)
FROM 'path/to/Inventory.csv'
DELIMITER ','
CSV HEADER;

-- Step 2: Create dimension tables
CREATE TABLE Dim_Customer (
    Customer_ID VARCHAR(50) PRIMARY KEY,
    Customer_Name VARCHAR(255),
    Customer_Address TEXT
);

CREATE TABLE Dim_Supplier (
    Supplier_ID SERIAL PRIMARY KEY,
    Supplier_Name VARCHAR(255),
    Supplier_Address TEXT
);

CREATE TABLE Dim_Product (
    Product_ID SERIAL PRIMARY KEY,
    Product_Name VARCHAR(255),
    Supplier_ID INTEGER REFERENCES Dim_Supplier(Supplier_ID)
);

CREATE TABLE Dim_Time (
    Time_ID INTEGER PRIMARY KEY,
    Day INTEGER,
    Month INTEGER,
    Year INTEGER,
    Quarter INTEGER
);

-- Step 3: Create fact tables
CREATE TABLE Fact_Sales (
    Order_ID VARCHAR(50) PRIMARY KEY,
    Customer_ID VARCHAR(50) REFERENCES Dim_Customer(Customer_ID),
    Product_ID INTEGER REFERENCES Dim_Product(Product_ID),
    Time_ID INTEGER REFERENCES Dim_Time(Time_ID),
    Quantity_Sold INTEGER,
    Sales_Revenue DECIMAL(10,2)
);

CREATE TABLE Fact_Feedback (
    Feedback_ID SERIAL PRIMARY KEY,
    Customer_ID VARCHAR(50) REFERENCES Dim_Customer(Customer_ID),
    Product_ID INTEGER REFERENCES Dim_Product(Product_ID),
    Time_ID INTEGER REFERENCES Dim_Time(Time_ID),
    Rating INTEGER,
    Review_Text TEXT
);

CREATE TABLE Fact_Inventory (
    Inventory_ID SERIAL PRIMARY KEY,
    Product_ID INTEGER REFERENCES Dim_Product(Product_ID),
    Time_ID INTEGER REFERENCES Dim_Time(Time_ID),
    Stock_Level INTEGER,
    Reorder_Point INTEGER
);

-- Step 4: ETL Process

-- 4.1 Sales data is already loaded in Staging_Sales from Sales_Transactions

-- 4.2 Feedback data is already loaded and extracted from JSON in Staging_Feedback

-- 4.3 Inventory data is already loaded with proper format

-- 4.4 Transform and Load Dimension Tables

-- Load Dim_Supplier (Note: This needs to be modified since supplier info is not in the new inventory structure)
-- You'll need to get supplier information from another source or modify the inventory structure

-- Load Dim_Product (modified to handle the new inventory structure)
INSERT INTO Dim_Product (Product_Name, Supplier_ID)
SELECT DISTINCT s.Product_Name, NULL as Supplier_ID  -- Supplier_ID is NULL since we don't have supplier info
FROM Staging_Sales s
LEFT JOIN Staging_Inventory i ON s.Product_Name = i.Product_ID::VARCHAR;

-- Load Dim_Customer
INSERT INTO Dim_Customer (Customer_ID, Customer_Name, Customer_Address)
SELECT DISTINCT Customer_ID, 
       'Customer ' || Customer_ID as Customer_Name,
       'Address for ' || Customer_ID as Customer_Address
FROM Staging_Sales
WHERE Customer_ID IS NOT NULL;

-- Load Dim_Time (modified to include inventory snapshot dates)
INSERT INTO Dim_Time (Time_ID, Day, Month, Year, Quarter)
SELECT DISTINCT 
    EXTRACT(EPOCH FROM Date)::INTEGER as Time_ID,
    EXTRACT(DAY FROM Date)::INTEGER as Day,
    EXTRACT(MONTH FROM Date)::INTEGER as Month,
    EXTRACT(YEAR FROM Date)::INTEGER as Year,
    EXTRACT(QUARTER FROM Date)::INTEGER as Quarter
FROM (
    SELECT Order_Date as Date FROM Staging_Sales
    UNION
    SELECT Feedback_Date FROM Staging_Feedback
    UNION
    SELECT Snapshot_Date FROM Staging_Inventory
) All_Dates
WHERE Date IS NOT NULL;

-- 4.5 Transform and Load Fact Tables

-- Transform and load sales data into Fact_Sales
INSERT INTO Fact_Sales (
    Order_ID,
    Customer_ID,
    Product_ID,
    Time_ID,
    Quantity_Sold,
    Sales_Revenue
)
SELECT 
    s.Order_ID,
    s.Customer_ID,
    p.Product_ID,
    EXTRACT(EPOCH FROM s.Order_Date)::INTEGER as Time_ID,
    s.Quantity_Sold,
    s.Sales_Revenue
FROM Staging_Sales s
JOIN Dim_Product p ON s.Product_Name = p.Product_Name
JOIN Dim_Time t ON EXTRACT(EPOCH FROM s.Order_Date)::INTEGER = t.Time_ID;

-- Transform and load feedback data into Fact_Feedback
INSERT INTO Fact_Feedback (
    Customer_ID,
    Product_ID,
    Time_ID,
    Rating,
    Review_Text
)
SELECT 
    f.Customer_ID,
    p.Product_ID,
    EXTRACT(EPOCH FROM f.Feedback_Date)::INTEGER as Time_ID,
    f.Rating,
    f.Review_Text
FROM Staging_Feedback f
JOIN Dim_Product p ON f.Product_Name = p.Product_Name
JOIN Dim_Time t ON EXTRACT(EPOCH FROM f.Feedback_Date)::INTEGER = t.Time_ID;

-- Transform and load inventory data into Fact_Inventory
INSERT INTO Fact_Inventory (
    Product_ID,
    Time_ID,
    Stock_Level,
    Reorder_Point
)
SELECT 
    p.Product_ID,
    EXTRACT(EPOCH FROM i.Snapshot_Date)::INTEGER as Time_ID,
    i.Stock_Level,
    i.Reorder_Point
FROM Staging_Inventory i
JOIN Dim_Product p ON i.Product_ID::VARCHAR = p.Product_Name
JOIN Dim_Time t ON EXTRACT(EPOCH FROM i.Snapshot_Date)::INTEGER = t.Time_ID;

-- Step 5: Clean up staging tables
DROP TABLE Staging_Sales;
DROP TABLE Staging_Feedback_Raw;
DROP TABLE Staging_Feedback;
DROP TABLE Staging_Inventory; 