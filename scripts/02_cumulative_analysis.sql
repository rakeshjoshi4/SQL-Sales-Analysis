-- Calculate the total sales per month 
-- and the running total of sales over time

SELECT 
	order_date,
	total_sales,
	running_total_sales,
	moving_price_total
FROM
(
	SELECT 
		DATETRUNC(MONTH, order_date) AS order_date,
		SUM(sales_amount) AS total_sales,
		AVG(price) AS avg_price,
		SUM(SUM(sales_amount)) OVER (ORDER BY DATETRUNC(MONTH, order_date)) AS running_total_sales,
		AVG(AVG(price)) OVER (ORDER BY DATETRUNC(MONTH, order_date)) AS moving_avg_price
	FROM gold.fact_sales
	WHERE order_date IS NOT NULL
	GROUP BY DATETRUNC(MONTH, order_date)
)t;

-- For year

SELECT 
	order_date,
	total_sales,
	running_total_sales,
	moving_price_total
FROM
(
	SELECT 
		DATETRUNC(YEAR, order_date) AS order_date,
		SUM(sales_amount) AS total_sales,
		AVG(price) AS avg_price
		SUM(SUM(sales_amount)) OVER (ORDER BY DATETRUNC(YEAR, order_date)) AS running_total_sales,
		AVG(AVG(price)) OVER (ORDER BY DATETRUNC(YEAR, order_date)) AS moving_avg_price
	FROM gold.fact_sales
	WHERE order_date IS NOT NULL
	GROUP BY DATETRUNC(YEAR, order_date)
)t;
