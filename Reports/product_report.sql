/*
================================================================================
Product Report 
=================================================================================
Purpose : 
	 - This report consolidates key product metrics and behaviors.

Highlights :
	1. Gathers essential fields such as prouct name, category, subcategory and cost.
	2. segments products by revenue to identify high-performers, mid-range or low_performers.
	3. Aggregates product-level mertrics :
		- total orders
		- total sales
		- total quantity sold
		- total customers (unique)
		- lifespan (in month)
	4. Calculates valuable KPIs
		- Recency
		- average order revenue (AOR)
		- average monthly revenue
===============================================================================================
*/
if object_id ('gold.report_products','v') is not null 
drop view gold.report_products

go

create view gold.report_products as
------------------------------------------------------------------------------------------
-- creating a base query that contains all product details necessary for building a report
-------------------------------------------------------------------------------------------
with cte_productdetails as 
(
select 
f.order_number,
f.product_key,
f.customer_key,
f.order_date,
f.sales_amount,
f.quantity,
f.price,
p.category_id,
p.category_name,
p.cost,
p.startdate,
p.product_name,
p.subcategory
from gold.fact_sales f
left join gold.dim_products p
on f.product_key = p.product_key
where order_date is not null
),
-----------------------------------------------------------------------------
-- product aggregrations : summarizes key metrics at the product level
------------------------------------------------------------------------------
cte_aggregationfor as 
(
select 
product_key,
product_name,
category_name,
subcategory,
cost,
count(distinct order_number) as totalorders,
count (distinct customer_key) as totalcustomers,
sum (sales_amount) as totalsales,
sum(quantity) as totalqunatity,
max(order_date) as last_date_of_sale,
datediff(month,min(order_date),max(order_date)) as lifespan,
round (avg (cast (price as float)),3) as avg_selling_price
from cte_productdetails
group by 
product_key,
product_name,
category_name,
subcategory,
cost
)
----------------------------------------------------------------------------------------------
-- final query : combines all product results into one output based on project requirements
-----------------------------------------------------------------------------------------------

select 
product_key,
product_name,
category_name,
subcategory,
cost,
last_date_of_sale,
datediff (month,last_date_of_sale,getdate()) as recency, -- calculating recency as per requried--
totalsales,
case
when totalsales >= 50000 then 'High Performer'
when totalsales >= 10000 then 'Mid Range'
else 'Low Performer'
end as segment_based_on_sales,
lifespan,
totalorders,
totalcustomers,
totalqunatity,
avg_selling_price,
-- Average order revenue (AOR)
case
	when totalorders = 0 then 0
	else totalsales / totalorders
end as average_order_revenue,
-- Average monthly revenue 
case
when lifespan = 0 then 0
else totalsales/lifespan
end as average_monthly_revenue
from cte_aggregationfor


