-- Checking for duplicates 
select customer_id,count(customer_id) from customer_behavior
group by customer_id
having count(customer_id) >1;

select customer_id,count(customer_id) from customers
group by customer_id
having count(customer_id) >1;

select partner_id,count(partner_id) from delivery_partners
group by partner_id
having count(partner_id) >1;

select order_id,count(order_id) from orders
group by order_id
having count(order_id) >1;

select payment_id,count(payment_id) from payments
group by payment_id
having count(payment_id) >1;

select restaurant_id,count(restaurant_id) from restaurants
group by restaurant_id
having count(restaurant_id) >1;

-- Handling Nulls
-- --orders table--  
UPDATE orders 
SET delivered_time = NULL 
WHERE status = 'Cancelled';
UPDATE orders 
SET delivery_fee = 0 
WHERE delivery_fee IS NULL;

-- customers table
UPDATE customers 
SET gender = 'Other' 
WHERE gender IS NULL OR gender = '';
UPDATE customers 
SET city = 'Unknown' 
WHERE city IS NULL;

-- restaurants table
UPDATE restaurants 
SET rating = (SELECT AVG(rating) FROM (SELECT rating FROM restaurants) AS temp)
WHERE rating IS NULL;

-- ratings table
UPDATE ratings 
SET feedback = 'No text feedback provided' 
WHERE feedback IS NULL OR feedback = '';

--  Standardizing City Names
UPDATE customers 
SET city = 'Bengaluru' 
WHERE city IN ('Bangalore', 'Bengluru');

-- Removing Duplicates 

DELETE FROM payments 
WHERE payment_id IN (
    SELECT payment_id FROM (
        SELECT payment_id, ROW_NUMBER() OVER(PARTITION BY order_id, amount ORDER BY payment_id) as row_num
        FROM payments
    ) t WHERE row_num > 1
);

-- Fixing invalid ratings 
UPDATE restaurants SET rating = 1.0 WHERE rating < 1.0;

-- Semantic Cleaning.
-- Check for "impossible" timestamps: (Did any order arrive before it was placed?)
ALTER TABLE orders 
MODIFY COLUMN order_time DATETIME,
MODIFY COLUMN delivered_time DATETIME;
SELECT * FROM orders WHERE delivered_time < order_time;

SELECT COUNT(*) AS anomalous_rows 
FROM orders 
WHERE delivered_time < order_time;

UPDATE orders 
SET delivered_time = NULL, 
    status = 'Data_Error' 
WHERE delivered_time < order_time;

SELECT COUNT(*) FROM orders WHERE delivered_time < order_time;

-- Check for out-of-range ratings
SELECT * FROM restaurants WHERE rating > 5.0 OR rating < 1.0;

-- Check for inconsistent text: (Are there spelling variations?)
SELECT DISTINCT city FROM customers;