/* 
==================================================================================
CUSTOMER REPORT
==================================================================================
Puprose :
	- This report consolidates key customer metrics and behaviours

Highlights
1. Gather essential fields such as names, ages, and transcation details.
2. Segments customer into categories (VIP, REGULAR, AND NEW) age groups.
3. Aggregates customer-level metrics :
	- total orders
	- total sales
	- total quantity purchased
	- total products
	- lifespan (in months)
4. Calculates valuable KPIs:
	- recency (months since last order)
	- average order value
	- average monthly spend
=========================================================================================
=========================================================================================

1. Base Query : retrieve core colums from table

==========================================================================================
*/
------------------------------------------------------------------------------------------
if object_id ('gold.report_customer','v') is not null 
drop view gold.report_customer;

go

create view gold.report_customer as 


with cte_base_query as (
select 
f.order_number,
f.product_key,
f.order_date,
f.sales_amount,
f.quantity,
c.customer_key,
c.customer_number,
concat (c.first_name,' ',c.last_name) as full_name,
datediff (year,c.birthdate,getdate()) as age
from gold.fact_sales f
left join gold.dim_customers c
on f.customer_key = c.customer_key
where f.order_date is not null
),
/*=========================================================================================

2. Intermidiate Query : perform all the aggregrations as per requirement at the customer 
level

==========================================================================================
*/
cte_intermidiate_query as 
(
select 
customer_key,
customer_number,
full_name,
age,
count(distinct order_number) as total_orders,
sum(sales_amount) as total_sales,
sum(quantity) as total_quantity,
count(distinct product_key) as total_products,
max(order_date) as last_order_date,
datediff(month,min(order_date), max(order_date)) as membership_span
from cte_base_query
group by 
customer_key,
customer_number,
full_name,
age
)
select 
customer_key,
customer_number,
full_name,
age,
case
	when age < 20  then 'under 20'
	WHEN age between 20 and 39 THEN '20-39'
	WHEN age between 40 and 59 THEN '20-59'
	WHEN age between 60 and 80 THEN '60-80'
	ELSE 'above 80'
end customer_segment_on_age,

case
	when membership_span >= 12 and total_sales > 5000 then 'VIP'
	WHEN membership_span >=12 AND total_sales <= 5000 THEN 'REGULAR'
	ELSE 'NEW'
end customer_segment_on_membershipspan,
last_order_date,
datediff(month,last_order_date,getdate()) as recency,
total_orders,
total_sales,
total_quantity,
total_products,
membership_span,
-- compute average order value (AVo)
total_sales/nullif (total_orders,0) as average_order_value,
-- compute average monthly spend
case 
when membership_span = 0 then 0
else total_sales/membership_span 
end as average_monthly_spend
from cte_intermidiate_query


