# SQL Sales Analysis Project

## Overview

This project demonstrates advanced sales analysis using Microsoft SQL Server on a data warehouse to uncover meaningful insights into customer behavior, product performance, and sales trends. The analysis uses SQL to explore, analyze, and derive actionable insights from structured data.

## Features

*   **Change Over Time Analysis**: Analyze sales performance trends over time using advanced date functions like `DATETRUNC` and `FORMAT`.
*   **Cumulative Analysis**: Calculate monthly sales totals and running totals to track growth over time.
*   **Part-to-Whole Analysis**: Identify categories contributing the most to overall sales using percentage calculations.
*   **Performance Analysis**: Evaluate yearly product performance by comparing sales to averages and previous years.
*   **Customer Report**: Generate a detailed report segmenting customers into VIP, Regular, and New categories while calculating key metrics like average order value and monthly spend.
*   **Product Report**: Create a comprehensive report consolidating product-level metrics such as total sales, orders, and customer engagement.

## Dataset Description

### Tables

*   `dim_customers`: Contains customer demographics such as name, country, gender, and birthdate.
*   `dim_products`: Includes product details such as category, subcategory, cost, and product line.
*   `fact_sales`: Stores transactional data including order details, sales amount, quantity sold, and dates.

### Key Columns

*   `customer_key`: Unique identifier for customers.
*   `product_key`: Unique identifier for products.
*   `sales_amount`: Total revenue generated per transaction.

## Getting Started

### Prerequisites

Ensure you have:

*   Microsoft SQL Server or a compatible database management system.
*   Access to the dataset files (CSV format) for customers, products, and sales.

### Installation Instructions

1.  **Clone the Repository**:

    ```
    git clone https://github.com/rakeshjoshi4/SQL-Sales-Analysis
    ```

2.  **Open SQL Scripts**:

    *   Use Microsoft SQL Server Management Studio (SSMS) or any compatible tool to execute the scripts in the `scripts` folder.

3.  **Initialize the Database and Load Data**:

    *   Execute the `00_init_database.sql` script to create the database, define the schema, and create the tables.
    *   Import the data from the CSV files (`gold.dim_customers.csv`, `gold.dim_products.csv`, and `gold.fact_sales.csv`) into their respective tables. You can use SQL Server Management Studio's import wizard or `BULK INSERT` statements.

## Key SQL Queries

### Change Over Time Analysis

1.  **Analyze monthly sales trends**

    ```sql
    SELECT
        DATETRUNC(MONTH, order_date) AS order_date,
        SUM(sales_amount) AS total_sales,
        COUNT(DISTINCT customer_key) AS total_customers,
        SUM(quantity) AS total_quantity
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(MONTH, order_date)
    ORDER BY DATETRUNC(MONTH, order_date);
    ```

2.  **Analyze yearly sales trends**

    ```sql
    SELECT
        YEAR(order_date) AS order_year,
        SUM(sales_amount) AS total_sales,
        COUNT(DISTINCT customer_key) AS total_customers,
        SUM(quantity) AS total_quantity
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY YEAR(order_date)
    ORDER BY YEAR(order_date);
    ```

### Cumulative Analysis

1.  **Calculate running total of monthly sales**

    ```sql
    SELECT
        order_date,
        total_sales,
        SUM(total_sales) OVER (ORDER BY order_date) AS running_total_sales
        AVG(avg_price) OVER (ORDER BY order_date) AS moving_price_total
    FROM (
        SELECT
            DATETRUNC(MONTH, order_date) AS order_date,
            SUM(sales_amount) AS total_sales
            AVG(price) AS avg_price
        FROM gold.fact_sales
        WHERE order_date IS NOT NULL
        GROUP BY DATETRUNC(MONTH, order_date)
    )t;
    ```

### Performance Analysis

1. **Compare yearly product performance**

    ```sql
	WITH yearly_product_sales AS (
	SELECT YEAR(f.order_date) AS order_year, p.product_name, SUM(f.sales_amount) AS current_sales
	FROM gold.fact_sales f
	LEFT JOIN gold.dim_products p ON p.product_key = f.product_key
	WHERE f.order_date IS NOT NULL
	GROUP BY YEAR(f.order_date), p.product_name
	)
	SELECT
	order_year,
	product_name,
	current_sales,
	AVG(current_sales) OVER (PARTITION BY product_name) AS avg_sales,
	current_sales - AVG(current_sales) OVER (PARTITION BY product_name) AS diff_avg,
	CASE
	WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above Avg'
	WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below Avg'
	ELSE 'Avg'
	END avg_change,
	-- year-over-year analysis
	LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS prev_yr_sales,
	current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS diff_prev,
	CASE
	WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
	WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
	ELSE 'No Change'
	END prev_yr_change
	FROM yearly_product_sales
	ORDER BY product_name, order_year;
    ```

### Part-to-Whole Analysis

1.  **Identify category contributions to total sales**

 ```
 WITH category_sales AS (
     SELECT p.category, SUM(f.sales_amount) AS total_sales
     FROM gold.fact_sales f
     LEFT JOIN gold.dim_products p ON p.product_key = f.product_key
     GROUP BY category
 )
 SELECT
     category,
     total_sales,
     SUM(total_sales) OVER() AS overall_sales,
     CONCAT(ROUND((CAST(total_sales AS FLOAT) / SUM(total_sales) OVER())*100, 2), '%') AS percentage_of_total
 FROM category_sales
 ORDER BY total_sales DESC;
 ```

### Customer Report

1.  **Generate Customer Report**:

 ```
 IF OBJECT_ID('gold.report_customers', 'V') IS NOT NULL
     DROP VIEW gold.report_customers;
 GO

 CREATE VIEW gold.report_customers AS

 WITH base_query AS(
     /*---------------------------------------------------------------------------
     1) Base Query: Retrieves core columns from tables
     ---------------------------------------------------------------------------*/
     SELECT
         f.order_number,
         f.product_key,
         f.order_date,
         f.sales_amount,
         f.quantity,
         c.customer_key,
         c.customer_number,
         CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
         DATEDIFF(year, c.birthdate, GETDATE()) age
     FROM gold.fact_sales f
     LEFT JOIN gold.dim_customers c
     ON c.customer_key = f.customer_key
     WHERE order_date IS NOT NULL
 ), customer_aggregation AS (
     /*---------------------------------------------------------------------------
     2) Customer Aggregations: Summarizes key metrics at the customer level
     ---------------------------------------------------------------------------*/
     SELECT 
         customer_key,
         customer_number,
         customer_name,
         age,
         COUNT(DISTINCT order_number) AS total_orders,
         SUM(sales_amount) AS total_sales,
         SUM(quantity) AS total_quantity,
         COUNT(DISTINCT product_key) AS total_products,
         MAX(order_date) AS last_order_date,
         DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan
     FROM base_query
     GROUP BY 
         customer_key,
         customer_number,
         customer_name,
         age
 )
 SELECT
     customer_key,
     customer_number,
     customer_name,
     age,
     CASE 
         WHEN age < 20 THEN 'Under 20'
         WHEN age BETWEEN 20 AND 29 THEN '20-29'
         WHEN age BETWEEN 30 AND 39 THEN '30-39'
         WHEN age BETWEEN 40 AND 49 THEN '40-49'
         ELSE '50 and above'
     END AS age_group,
     CASE 
         WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
         WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
         ELSE 'New'
     END AS customer_segment,
     last_order_date,
     DATEDIFF(month, last_order_date, GETDATE()) AS recency,
     total_orders,
     total_sales,
     total_quantity,
     total_products,
     lifespan,
     -- Compute average order value (AVO)
     CASE WHEN total_sales = 0 THEN 0
          ELSE total_sales / total_orders
     END AS avg_order_value,
     -- Compute average monthly spend
     CASE WHEN lifespan = 0 THEN total_sales
          ELSE total_sales / lifespan
     END AS avg_monthly_spend
 FROM customer_aggregation;
 ```

#### Product Report

1.  **Generate Product Report**:

 ```
 IF OBJECT_ID('gold.report_products', 'V') IS NOT NULL
     DROP VIEW gold.report_products;
 GO

 CREATE VIEW gold.report_products AS

 WITH base_query AS (
     /*---------------------------------------------------------------------------
     1) Base Query: Retrieves core columns from fact_sales and dim_products
     ---------------------------------------------------------------------------*/
     SELECT
         f.order_number,
         f.order_date,
         f.customer_key,
         f.sales_amount,
         f.quantity,
         p.product_key,
         p.product_name,
         p.category,
         p.subcategory,
         p.cost
     FROM gold.fact_sales f
     LEFT JOIN gold.dim_products p ON f.product_key = p.product_key
     WHERE order_date IS NOT NULL  -- only consider valid sales dates
 ), product_aggregations AS (
     /*---------------------------------------------------------------------------
     2) Product Aggregations: Summarizes key metrics at the product level
     ---------------------------------------------------------------------------*/
     SELECT
         product_key,
         product_name,
         category,
         subcategory,
         cost,
         DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan,
         MAX(order_date) AS last_sale_date,
         COUNT(DISTINCT order_number) AS total_orders,
         COUNT(DISTINCT customer_key) AS total_customers,
         SUM(sales_amount) AS total_sales,
         SUM(quantity) AS total_quantity,
         ROUND(AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity, 0)),1) AS avg_selling_price
     FROM base_query
     GROUP BY
         product_key,
         product_name,
         category,
         subcategory,
         cost
 )
 /*---------------------------------------------------------------------------
 3) Final Query: Combines all product results into one output
 ---------------------------------------------------------------------------*/
 SELECT 
     product_key,
     product_name,
     category,
     subcategory,
     cost,
     last_sale_date,
     DATEDIFF(MONTH, last_sale_date, GETDATE()) AS recency_in_months,
     CASE
         WHEN total_sales > 50000 THEN 'High-Performer'
         WHEN total_sales >= 10000 THEN 'Mid-Range'
         ELSE 'Low-Performer'
     END AS product_segment,
     lifespan,
     total_orders,
     total_sales,
     total_quantity,
     total_customers,
     avg_selling_price,
     -- Average Order Revenue (AOR)
     CASE 
         WHEN total_orders = 0 THEN 0
         ELSE total_sales / total_orders
     END AS avg_order_revenue,
     -- Average Monthly Revenue
     CASE
         WHEN lifespan = 0 THEN total_sales
         ELSE total_sales / lifespan
     END AS avg_monthly_revenue
 FROM product_aggregations;
 ```

## Findings

The SQL Sales Analysis project provided several actionable insights:

1.  **Sales Trends**:
    *   Monthly and yearly trends showed consistent growth in certain periods.
    *   Cumulative analysis highlighted steady revenue growth over time.

2.  **Category Contributions**:
    *   Certain categories contributed significantly to overall revenue.

3.  **Customer Insights**:
    *   Segmented customers into VIPs and regular buyers based on their spending habits.

4.  **Product Performance**:
    *   Identified high-performing products driving revenue growth.

## Conclusion

The SQL Sales Analysis project successfully extracted meaningful insights from structured data stored in a relational database. These findings can inform strategic decisions related to marketing strategies, product management, customer retention programs, and operational efficiency.

## Recommendations

1.  **Product Strategy**: Focus on high-performing products while exploring ways to improve underperforming ones.
2.  **Customer Engagement**: Develop loyalty programs for VIP customers and targeted campaigns for new or infrequent buyers.
3.  **Geographic Expansion**: Identify regions with untapped potential for increased market penetration.
