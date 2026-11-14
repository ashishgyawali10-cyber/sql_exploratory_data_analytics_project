--  ADVANCE DATA ANALYTICS PROJECTS--
-- CHANGE OVER TIME ANALYSIS
SELECT 
YEAR(ORDER_DATE) AS YEAR_INFO,
SUM(sales_amount) AS TOT_SALES_PER_MONTH,
COUNT(DISTINCT customer_key) AS TOT_CUSTOMERS,
SUM(quantity) AS TOTQUNATITY
FROM GOLD.fact_sales
GROUP BY YEAR(ORDER_DATE)
HAVING YEAR(ORDER_DATE) IS NOT NULL
ORDER BY YEAR(ORDER_DATE) ASC


-- CUMULATIVE ANALYSIS
-- CALCULATE THE TOTAL SALES PER MONTH AND THE RUNNING TOTAL OF SALES OVER ITME
SELECT 
ORDER_DATE,
TOTSALES,
SUM(TOTSALES) OVER (ORDER BY ORDER_DATE ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS CUMULATIVE_SALES
FROM (
SELECT 
DATETRUNC(MONTH, ORDER_DATE) AS ORDER_DATE,
SUM(sales_amount) AS TOTSALES
FROM GOLD.fact_sales
GROUP BY DATETRUNC(MONTH, ORDER_DATE)
HAVING DATETRUNC(MONTH, ORDER_DATE) IS NOT NULL
)T


-- PERFORMANCE ANALYSIS
-- ANALYZE THE YEARLY PERFORMACE OF PRODUCTS BY COMPARING EACH PRODUCTS SALES TO BOTH ITS 
-- AVERAGE SALES PERFORMACE AND THE PERVIOUS YEARS SALES
select 
product_name,
year_info,
total_sales_per_year,
avgsales,
total_sales_per_year-avgsales as performace_vs_avgsales,
case
when total_sales_per_year-avgsales > 0 then'above average'
when total_sales_per_year-avgsales < 0 then 'below average'
else 'same as average'
end as performace_agaisnt_average_info,
total_sales_per_year-previousyearsales as performance_vs_previousyearsales,
case
when total_sales_per_year-previousyearsales > 0 then'incresed'
when total_sales_per_year-previousyearsales < 0 then 'decreased'
else 'no change'
end as performace_agaisnt_previousyear_info
from (
select 
product_name,
year_info,
total_sales_per_year,
avg(total_sales_per_year)over (partition by product_name) as avgsales,
lag(total_sales_per_year) over ( partition by product_name order by year_info asc) as previousyearsales
from (
SELECT 
B.product_name,
year (A.order_date) as year_info,
sum(a.sales_amount) as total_sales_per_year
FROM GOLD.fact_sales A
LEFT JOIN GOLD.dim_products B
ON A.product_key = B.product_key
group by year(a.order_date), b.product_name
having year(a.order_date)  is not null
)t
)x
order by product_name, year_info asc



-- PART TO WHOLE ANALYSIS --
-- WHICH CATEGORIES CONTRIBUTE THE MOST TO OVERALL SALES
SELECT 
CATEGORY_NAME,
TOTALSALESPERCATEGORY,
TOTALOVERALLSALES,
CONCAT (ROUND ((CAST (TOTALSALESPERCATEGORY AS float)/TOTALOVERALLSALES)*100,3),' ','%')  AS PERCENTAGE_CONTRIBUTION
FROM 
(
SELECT *,
SUM(TOTALSALESPERCATEGORY) OVER() AS TOTALOVERALLSALES
FROM
(
SELECT 
B.category_name,
SUM(A.sales_amount) AS TOTALSALESPERCATEGORY
FROM GOLD.fact_sales A
LEFT JOIN GOLD.dim_products B
ON A.product_key = B.product_key
GROUP BY B.category_name
)T
)X

--DATA SEGMENTATION USING CASE STATEMENTS --

-- SEGMENT PRODUCTS INTO COST RANGES AND 
-- COUNT HOW MANY PRODUCTS FALL INTO EACH SEGMENT

SELECT 
COST_SEGMENTATION,
COUNT (product_name) AS NOOFPRODUCTS

FROM (
SELECT 
PRODUCT_NAME,
product_key,
cost,
CASE
WHEN cost BETWEEN 0 AND 500 THEN 'LOW COST SEGMENT'
WHEN COST BETWEEN 501 AND 1500 THEN 'MEDIUM COST SEGMENT'
ELSE 'HIGH COST SEGMENT'
END AS COST_SEGMENTATION
FROM GOLD.dim_products
)T
GROUP BY COST_SEGMENTATION
ORDER BY NOOFPRODUCTS ASC


/* GROUP CUSTOMERS INTO 3 SEGMENTS BASED ON THEIR SPENDING BEHAVIOUR
-- VIP : AT LEAST 12 MONTHS OF HISTORY AND SPENDING MORE THAN 5000
-- REGULAR : AT LEAST 12 MONTHS OF HISTORY BUT SPENDING OF 5000 OR LESS
-- NEW : LIFESPAN LESS THAN 12 MONTHS
AND FIND THE TOTAL NUMBER OF CUSTOMERS BY EACH GROUP
*/

WITH CTE_CUSTOMERDT AS 
(
SELECT 
A.customer_key,
CONCAT (first_name,' ',last_name) AS FULL_NAME,
SUM (B.sales_amount) AS TOTALSPEND
FROM GOLD.dim_customers A
LEFT JOIN GOLD.fact_sales B
ON A.customer_key = B.customer_key
GROUP BY A.customer_key, CONCAT (first_name,' ',last_name)
)
,CTE_CUSTOMERMEMBERSHIPAGE AS
(
SELECT 
customer_key,
DATEDIFF(MONTH,FIRST_ORDERDATE,LAST_ORDERDATE) AS MEMBERSHIP_SPAN
FROM (
SELECT 
customer_key,
MIN(order_date) AS FIRST_ORDERDATE,
MAX(order_date) AS LAST_ORDERDATE
FROM GOLD.fact_sales
GROUP BY customer_key
)T
)
SELECT 
CUSTOMER_SEGMENT,
COUNT (customer_key) AS TOTAL_NUMBEROFCUSTOMER

FROM (
SELECT 
CTA.customer_key,
CASE
WHEN MEMBERSHIP_SPAN >=12 AND TOTALSPEND > 5000 THEN 'VIP'
WHEN MEMBERSHIP_SPAN >=12 AND TOTALSPEND <= 5000 THEN 'REGULAR'
WHEN MEMBERSHIP_SPAN < 12 THEN 'NEW'
ELSE NULL
END AS CUSTOMER_SEGMENT
FROM CTE_CUSTOMERDT AS CTA
LEFT JOIN CTE_CUSTOMERMEMBERSHIPAGE AS CTB
ON CTA.customer_key = CTB.customer_key
)V
GROUP BY CUSTOMER_SEGMENT


