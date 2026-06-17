-- Problem 1: Delivery Delays
-- Q1	Which restaurants are associated with the longest average delivery times?-- 
SELECT r.restaurant_name, 
       AVG(TIMESTAMPDIFF(MINUTE, o.order_time, o.delivered_time)) AS avg_delivery_time
FROM orders o
JOIN restaurants r ON o.restaurant_id = r.restaurant_id
WHERE o.status = 'Delivered'
GROUP BY 1
ORDER BY avg_delivery_time DESC
LIMIT 5;

-- Q2	Which delivery partners have the highest average time per order?
SELECT 
    p.partner_name, 
    p.vehicle_type,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, o.order_time, o.delivered_time)), 2) AS avg_delivery_time_minutes
FROM orders o
JOIN delivery_partners p ON o.partner_id = p.partner_id
WHERE o.status = 'Delivered' -- We only calculate time for successful deliveries
GROUP BY p.partner_id, p.partner_name, p.vehicle_type
ORDER BY avg_delivery_time_minutes DESC;

-- Q3	Which cities experience the most delivery delays?
SELECT 
    c.city,
    COUNT(o.order_id) AS total_delivered_orders,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, o.order_time, o.delivered_time)), 2) AS avg_delivery_time,
    -- Count how many orders exceeded the 45-minute threshold
    SUM(CASE WHEN TIMESTAMPDIFF(MINUTE, o.order_time, o.delivered_time) > 45 THEN 1 ELSE 0 END) AS delayed_orders_count,
    -- Calculate the percentage of orders that were delayed
    ROUND(SUM(CASE WHEN TIMESTAMPDIFF(MINUTE, o.order_time, o.delivered_time) > 45 THEN 1 ELSE 0 END) * 100.0 / COUNT(o.order_id), 2) AS delay_percentage
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.status = 'Delivered'
GROUP BY c.city
ORDER BY delay_percentage DESC;

-- Q4	Are delivery delays increasing or decreasing over time?
WITH MonthlyDeliveryStats AS (
    SELECT 
        DATE_FORMAT(order_time, '%Y-%m') AS order_month,
        ROUND(AVG(TIMESTAMPDIFF(MINUTE, order_time, delivered_time)), 2) AS avg_delivery_time,
        COUNT(order_id) AS total_orders
    FROM orders
    WHERE status = 'Delivered'
    GROUP BY 1
)
SELECT 
    order_month,
    avg_delivery_time,
    -- Get the previous month's average using LAG()
    LAG(avg_delivery_time) OVER (ORDER BY order_month) AS previous_month_avg,
    -- Calculate the difference
    ROUND(avg_delivery_time - LAG(avg_delivery_time) OVER (ORDER BY order_month), 2) AS month_over_month_change
FROM MonthlyDeliveryStats
ORDER BY order_month;



-- Problem 2: Order Cancellations

-- Q1	Which restaurants receive the highest volume of cancellations?
SELECT 
    r.restaurant_name, 
    r.cuisine_type,
    COUNT(o.order_id) AS total_cancellations,
    -- Also calculate the percentage to see if a restaurant is just busy or actually problematic
    ROUND(COUNT(o.order_id) * 100.0 / (SELECT COUNT(*) FROM orders WHERE restaurant_id = r.restaurant_id), 2) AS cancellation_rate_pct
FROM orders o
JOIN restaurants r ON o.restaurant_id = r.restaurant_id
WHERE o.status = 'Cancelled'
GROUP BY r.restaurant_id, r.restaurant_name, r.cuisine_type
ORDER BY total_cancellations DESC
LIMIT 10;

-- Q2: Cities with the highest cancellation rates?
SELECT c.city, 
       COUNT(CASE WHEN o.status = 'Cancelled' THEN 1 END) * 100.0 / COUNT(*) AS cancellation_rate
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY 1
ORDER BY cancellation_rate DESC;

-- Q3	Is there a correlation between delivery delays and cancellations?
WITH CityMetrics AS (
    SELECT 
        c.city,
        -- Metric 1: Avg Delivery Time for successful orders
        ROUND(AVG(TIMESTAMPDIFF(MINUTE, o.order_time, o.delivered_time)), 2) AS avg_delivery_time,
        -- Metric 2: Cancellation Rate Percentage
        ROUND(COUNT(CASE WHEN o.status = 'Cancelled' THEN 1 END) * 100.0 / COUNT(*), 2) AS cancellation_rate
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.city
)
SELECT 
    city, 
    avg_delivery_time, 
    cancellation_rate,
    -- Analysis Logic
    CASE 
        WHEN avg_delivery_time > 40 AND cancellation_rate > 15 THEN 'High Delay - High Cancellation (Strong Correlation)'
        WHEN avg_delivery_time < 30 AND cancellation_rate < 5 THEN 'Efficient City (Low Issues)'
        ELSE 'Moderate / No Clear Correlation'
    END AS correlation_category
FROM CityMetrics
ORDER BY avg_delivery_time DESC;

-- Q4	On which days and at which times do cancellations peak?
-- Part A: Cancellations by Day of the Week
SELECT 
    DAYNAME(order_time) AS day_of_week, 
    COUNT(*) AS total_cancellations,
    -- Calculate percentage of weekly cancellations
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM orders WHERE status = 'Cancelled'), 2) AS pct_of_total_cancellations
FROM orders
WHERE status = 'Cancelled'
GROUP BY day_of_week
ORDER BY total_cancellations DESC;

-- Part B: Cancellations by Hour of the Day
SELECT 
    HOUR(order_time) AS hour_of_day, 
    COUNT(*) AS total_cancellations
FROM orders
WHERE status = 'Cancelled'
GROUP BY hour_of_day
ORDER BY total_cancellations DESC
LIMIT 5;

-- --monthly lost -- 
SELECT 
    ROUND(SUM(order_amount + delivery_fee) / 36, 2) AS monthly_revenue_loss
FROM orders 
WHERE status = 'Cancelled';




-- Problem 3: Revenue Optimization

-- Q1	Which restaurants generate the highest total revenue?

SELECT 
    r.restaurant_name, 
    r.cuisine_type,
    COUNT(o.order_id) AS successful_orders,
    -- We use SUM to get the total money generated
    SUM(o.order_amount) AS total_revenue,
    -- We calculate the Average Order Value (AOV) for extra context
    ROUND(AVG(o.order_amount), 2) AS avg_order_value
FROM orders o
JOIN restaurants r ON o.restaurant_id = r.restaurant_id
WHERE o.status = 'Delivered' -- Revenue is only realized on successful deliveries
GROUP BY r.restaurant_id, r.restaurant_name, r.cuisine_type
ORDER BY total_revenue DESC
LIMIT 10;

-- Q2	Which cities contribute the most to overall company revenue?
SELECT 
    c.city,
    COUNT(o.order_id) AS total_orders,
    SUM(o.order_amount) AS city_revenue,
    -- Calculate what percentage of the WHOLE company's revenue comes from this city
    ROUND(
        SUM(o.order_amount) * 100.0 / (SELECT SUM(order_amount) FROM orders WHERE status = 'Delivered'), 
        2
    ) AS pct_of_total_revenue
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.status = 'Delivered'
GROUP BY c.city
ORDER BY city_revenue DESC;

-- Q3	Which payment methods are most popular and most valuable?
SELECT 
    payment_mode,
    -- Popularity Metric: How many times was it used?
    COUNT(payment_id) AS total_transactions,
    -- Value Metric: How much total money was processed?
    SUM(amount) AS total_revenue_collected,
    -- Context Metric: What is the Average Transaction Value (ATV)?
    ROUND(AVG(amount), 2) AS avg_transaction_value,
    -- Percentage of total transactions
    ROUND(COUNT(payment_id) * 100.0 / (SELECT COUNT(*) FROM payments), 2) AS popularity_percentage
FROM payments
GROUP BY payment_mode
ORDER BY total_revenue_collected DESC;

-- Q4: Monthly Revenue Trends 
SELECT DATE_FORMAT(order_time, '%Y-%m') AS month,
       SUM(order_amount) AS monthly_revenue,
       LAG(SUM(order_amount)) OVER (ORDER BY DATE_FORMAT(order_time, '%Y-%m')) AS prev_month_revenue
FROM orders
WHERE status = 'Delivered'
GROUP BY 1;


-- Problem 4: Customer Retention

-- Q1: Top 10 High-Value Customers (Lifetime Spending)
SELECT c.customer_name, SUM(o.order_amount) as total_spent
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.status = 'Delivered'
GROUP BY 1
ORDER BY total_spent DESC
LIMIT 10;

-- Q2	Which customers order most frequently, and what is their average order value?
SELECT 
    c.customer_id,
    c.customer_name,
    c.city,
    -- Frequency: Total number of successful orders
    COUNT(o.order_id) AS total_orders,
    -- Average Order Value (AOV)
    ROUND(AVG(o.order_amount), 2) AS average_order_value,
    -- Total Lifetime Spend (LTV)
    SUM(o.order_amount) AS total_spent
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.status = 'Delivered'
GROUP BY c.customer_id, c.customer_name, c.city
ORDER BY total_orders DESC
LIMIT 20;

-- Q3	Which customers have gone inactive in the last 90 days?
SELECT 
    c.customer_id, 
    c.customer_name, 
    c.city,
    MAX(o.order_time) AS last_order_date,
    -- Calculate days since last order relative to the project "current date" (Jan 2025)
    DATEDIFF('2025-01-31', MAX(o.order_time)) AS days_since_last_order
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.status = 'Delivered'
GROUP BY c.customer_id, c.customer_name, c.city
HAVING days_since_last_order > 90
ORDER BY days_since_last_order DESC;

-- Q4	What behavioural patterns signal that a customer is about to churn?
WITH CustomerBehavior AS (
    SELECT 
        o.customer_id,
        c.customer_name,
        -- Get the rating of their most recent order
        FIRST_VALUE(r.customer_rating) OVER(PARTITION BY o.customer_id ORDER BY o.order_time DESC) AS latest_rating,
        -- Count how many of their last 5 orders were cancelled
        SUM(CASE WHEN o.status = 'Cancelled' THEN 1 ELSE 0 END) OVER(PARTITION BY o.customer_id ORDER BY o.order_time DESC ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS recent_cancellations,
        -- Calculate their lifetime average rating to compare
        AVG(r.customer_rating) OVER(PARTITION BY o.customer_id) AS lifetime_avg_rating,
        -- Get the date of the last order
        MAX(o.order_time) OVER(PARTITION BY o.customer_id) AS last_order_date
    FROM orders o
    LEFT JOIN ratings r ON o.order_id = r.order_id
    JOIN customers c ON o.customer_id = c.customer_id
)
SELECT DISTINCT
    customer_id,
    customer_name,
    latest_rating,
    lifetime_avg_rating,
    recent_cancellations,
    CASE 
        WHEN latest_rating <= 2 THEN 'Signal: Bad Last Experience'
        WHEN recent_cancellations >= 2 THEN 'Signal: Frequent Order Failures'
        WHEN latest_rating < lifetime_avg_rating THEN 'Signal: Declining Satisfaction'
        ELSE 'Healthy'
    END AS churn_risk_signal
FROM CustomerBehavior
WHERE latest_rating IS NOT NULL
ORDER BY recent_cancellations DESC, latest_rating ASC;


-- Problem 5: Delivery Partner Performance
-- Q1	Who are the fastest delivery partners based on average delivery time?
SELECT 
    p.partner_id,
    p.partner_name,
    p.vehicle_type,
    -- Calculate average delivery time in minutes
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, o.order_time, o.delivered_time)), 2) AS avg_delivery_time,
    -- Count total successful deliveries to ensure consistency
    COUNT(o.order_id) AS total_successful_deliveries
FROM delivery_partners p
JOIN orders o ON p.partner_id = o.partner_id
WHERE o.status = 'Delivered'
GROUP BY p.partner_id, p.partner_name, p.vehicle_type
HAVING total_successful_deliveries > 20 -- Ensuring they are experienced partners
ORDER BY avg_delivery_time ASC -- ASCENDING because lower time = faster speed
LIMIT 10;

-- Q2	Which partners handle the highest volume of successful deliveries?
SELECT 
    p.partner_id,
    p.partner_name,
    p.vehicle_type,
    -- Count only successful deliveries
    COUNT(o.order_id) AS total_successful_deliveries,
    -- Calculate their "Success Rate" (Delivered vs. Total assigned)
    ROUND(COUNT(o.order_id) * 100.0 / (SELECT COUNT(*) FROM orders WHERE partner_id = p.partner_id), 2) AS success_rate_pct
FROM delivery_partners p
JOIN orders o ON p.partner_id = o.partner_id
WHERE o.status = 'Delivered'
GROUP BY p.partner_id, p.partner_name, p.vehicle_type
ORDER BY total_successful_deliveries DESC
LIMIT 10;

-- Q3	Which partners are associated with the most cancellations or delays?
SELECT 
    p.partner_id,
    p.partner_name,
    COUNT(o.order_id) AS total_assigned_orders,
    -- Metric 1: Count of Cancellations
    SUM(CASE WHEN o.status = 'Cancelled' THEN 1 ELSE 0 END) AS cancellation_count,
    -- Metric 2: Count of Delays (> 45 mins)
    SUM(CASE WHEN o.status = 'Delivered' AND TIMESTAMPDIFF(MINUTE, o.order_time, o.delivered_time) > 45 THEN 1 ELSE 0 END) AS delay_count,
    -- Metric 3: Total Failure Rate (Cancellations + Delays) as a Percentage
    ROUND(
        (SUM(CASE WHEN o.status = 'Cancelled' THEN 1 ELSE 0 END) + 
         SUM(CASE WHEN o.status = 'Delivered' AND TIMESTAMPDIFF(MINUTE, o.order_time, o.delivered_time) > 45 THEN 1 ELSE 0 END)) 
        * 100.0 / COUNT(o.order_id), 2
    ) AS total_failure_rate_pct
FROM delivery_partners p
JOIN orders o ON p.partner_id = o.partner_id
GROUP BY p.partner_id, p.partner_name
HAVING total_assigned_orders > 10 -- Exclude new partners who might just be learning
ORDER BY total_failure_rate_pct DESC
LIMIT 10;

-- Q4	What is the average customer rating received per delivery partner?
SELECT 
    p.partner_id,
    p.partner_name,
    p.vehicle_type,
    -- Calculate Average Rating
    ROUND(AVG(r.customer_rating), 2) AS avg_rating,
    -- Count of ratings received (Not every order gets a rating)
    COUNT(r.rating_id) AS total_ratings_received,
    -- Categorize the partner based on their score
    CASE 
        WHEN AVG(r.customer_rating) >= 4.5 THEN 'Elite (Top Tier)'
        WHEN AVG(r.customer_rating) >= 3.5 THEN 'Average (Good)'
        ELSE 'Below Expectations (Needs Training)'
    END AS performance_category
FROM delivery_partners p
JOIN orders o ON p.partner_id = o.partner_id
JOIN ratings r ON o.order_id = r.order_id
GROUP BY p.partner_id, p.partner_name, p.vehicle_type
HAVING total_ratings_received > 5 -- Filter for partners with enough feedback
ORDER BY avg_rating DESC;


--  Cuisine Analysis:-

-- 1. Which cuisine type has the highest average rating?
SELECT cuisine_type, ROUND(AVG(rating), 2) AS avg_cuisine_rating, COUNT(*) AS restaurant_count
FROM restaurants
GROUP BY cuisine_type
ORDER BY avg_cuisine_rating DESC;

-- 2. Which cuisine type is most likely to be cancelled?
SELECT r.cuisine_type, 
       COUNT(CASE WHEN o.status = 'Cancelled' THEN 1 END) * 100.0 / COUNT(*) AS cancellation_rate
FROM orders o
JOIN restaurants r ON o.restaurant_id = r.restaurant_id
GROUP BY r.cuisine_type
ORDER BY cancellation_rate DESC;

-- 3. What is the average order value for "Fast Food" vs "Fine Dining"?-- 
SELECT 
    CASE 
        WHEN cuisine_type IN ('Burger', 'Pizza', 'Sandwich', 'Street Food') THEN 'Fast Food'
        WHEN cuisine_type IN ('North Indian', 'Continental', 'Italian', 'Chinese') THEN 'Main Course/Fine Dining'
        ELSE 'Other'
    END AS restaurant_category,
    ROUND(AVG(order_amount), 2) AS avg_order_value
FROM orders o
JOIN restaurants r ON o.restaurant_id = r.restaurant_id
WHERE o.status = 'Delivered'
GROUP BY 1;


-- Geographic Deep-Dives-- 

-- 1. Top 3 restaurants in Mumbai by revenue.
SELECT r.restaurant_name, SUM(o.order_amount) AS total_revenue
FROM orders o
JOIN restaurants r ON o.restaurant_id = r.restaurant_id
WHERE r.city = 'Mumbai' AND o.status = 'Delivered'
GROUP BY r.restaurant_id, r.restaurant_name
ORDER BY total_revenue DESC
LIMIT 3;

SELECT r.restaurant_name, SUM(o.order_amount) AS total_revenue
FROM orders o
JOIN restaurants r ON o.restaurant_id = r.restaurant_id
WHERE r.city = 'Chennai' AND o.status = 'Delivered'
GROUP BY r.restaurant_id, r.restaurant_name
ORDER BY total_revenue DESC
LIMIT 3;

SELECT r.restaurant_name, SUM(o.order_amount) AS total_revenue
FROM orders o
JOIN restaurants r ON o.restaurant_id = r.restaurant_id
WHERE r.city = 'Jaipur' AND o.status = 'Delivered'
GROUP BY r.restaurant_id, r.restaurant_name
ORDER BY total_revenue DESC
LIMIT 3;

SELECT r.restaurant_name, SUM(o.order_amount) AS total_revenue
FROM orders o
JOIN restaurants r ON o.restaurant_id = r.restaurant_id
WHERE r.city = 'Delhi' AND o.status = 'Delivered'
GROUP BY r.restaurant_id, r.restaurant_name
ORDER BY total_revenue DESC
LIMIT 3;

SELECT r.restaurant_name, SUM(o.order_amount) AS total_revenue
FROM orders o
JOIN restaurants r ON o.restaurant_id = r.restaurant_id
WHERE r.city = 'Ahmedabad' AND o.status = 'Delivered'
GROUP BY r.restaurant_id, r.restaurant_name
ORDER BY total_revenue DESC
LIMIT 3;

SELECT r.restaurant_name, SUM(o.order_amount) AS total_revenue
FROM orders o
JOIN restaurants r ON o.restaurant_id = r.restaurant_id
WHERE r.city = 'Kolkata' AND o.status = 'Delivered'
GROUP BY r.restaurant_id, r.restaurant_name
ORDER BY total_revenue DESC
LIMIT 3;

SELECT r.restaurant_name, SUM(o.order_amount) AS total_revenue
FROM orders o
JOIN restaurants r ON o.restaurant_id = r.restaurant_id
WHERE r.city = 'Surat' AND o.status = 'Delivered'
GROUP BY r.restaurant_id, r.restaurant_name
ORDER BY total_revenue DESC
LIMIT 3;

SELECT r.restaurant_name, SUM(o.order_amount) AS total_revenue
FROM orders o
JOIN restaurants r ON o.restaurant_id = r.restaurant_id
WHERE r.city = 'Hyderabad' AND o.status = 'Delivered'
GROUP BY r.restaurant_id, r.restaurant_name
ORDER BY total_revenue DESC
LIMIT 3;

SELECT r.restaurant_name, SUM(o.order_amount) AS total_revenue
FROM orders o
JOIN restaurants r ON o.restaurant_id = r.restaurant_id
WHERE r.city = 'Pune' AND o.status = 'Delivered'
GROUP BY r.restaurant_id, r.restaurant_name
ORDER BY total_revenue DESC
LIMIT 3;

SELECT r.restaurant_name, SUM(o.order_amount) AS total_revenue
FROM orders o
JOIN restaurants r ON o.restaurant_id = r.restaurant_id
WHERE r.city = 'Bengaluru' AND o.status = 'Delivered'
GROUP BY r.restaurant_id, r.restaurant_name
ORDER BY total_revenue DESC
LIMIT 3;

-- 2. Average delivery time in Delhi vs Pune.
SELECT r.city, ROUND(AVG(TIMESTAMPDIFF(MINUTE, o.order_time, o.delivered_time)), 2) AS avg_delivery_time
FROM orders o
JOIN restaurants r ON o.restaurant_id = r.restaurant_id
WHERE r.city IN ('Delhi', 'Pune') AND o.status = 'Delivered'
GROUP BY r.city;

--  Payment & Feedback Correlation
-- 1. Do customers who pay with "Cash on Delivery" leave lower ratings?
SELECT p.payment_mode, ROUND(AVG(r.customer_rating), 2) AS avg_rating
FROM payments p
JOIN ratings r ON p.order_id = r.order_id
GROUP BY p.payment_mode
ORDER BY avg_rating ASC;

-- 2. Most common feedback keyword for 1-star ratings (Checking for "delay").
SELECT COUNT(*) AS total_complaints_about_delay
FROM ratings
WHERE customer_rating = 1 AND feedback LIKE '%delay%';

-- 3. % of 5-star ratings from orders delivered in under 20 minutes.
SELECT 
    (COUNT(CASE WHEN TIMESTAMPDIFF(MINUTE, o.order_time, o.delivered_time) < 20 THEN 1 END) * 100.0 / COUNT(*)) AS pct_fast_5star_orders
FROM orders o
JOIN ratings r ON o.order_id = r.order_id
WHERE r.customer_rating = 5;

--  Advanced Time Analysis
-- 1 Peak order hour for "Breakfast" (6 AM - 11 AM).
SELECT HOUR(order_time) AS order_hour, COUNT(*) AS total_orders
FROM orders
WHERE HOUR(order_time) BETWEEN 6 AND 11
GROUP BY order_hour
ORDER BY total_orders DESC;

-- 2. Peak order hour for "Late Night" (11 PM - 3 AM).
SELECT HOUR(order_time) AS order_hour, COUNT(*) AS total_orders
FROM orders
WHERE HOUR(order_time) >= 23 OR HOUR(order_time) <= 3
GROUP BY order_hour
ORDER BY total_orders DESC;

-- 3. Total revenue generated on Weekends vs Weekdays.
SELECT 
    CASE WHEN DAYNAME(order_time) IN ('Saturday', 'Sunday') THEN 'Weekend' ELSE 'Weekday' END AS day_type,
    SUM(order_amount) AS total_revenue
FROM orders
WHERE status = 'Delivered'
GROUP BY 1;


CREATE TABLE customer_behaviour AS
SELECT 
    c.customer_id,
    COUNT(o.order_id) AS total_orders,
    SUM(o.order_amount) AS total_spending,
    ROUND(AVG(o.order_amount), 2) AS avg_order_value,
    DATEDIFF('2025-01-31', MAX(o.order_time)) AS last_order_days,
    CASE 
        WHEN DATEDIFF('2025-01-31', MAX(o.order_time)) > 90 OR COUNT(o.order_id) = 0 THEN 1 
        ELSE 0 
    END AS churn_flag
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id AND o.status = 'Delivered'
GROUP BY c.customer_id;

select * from customer_behaviour;

-- 1.How many VIP vs. Churned customers do we have?
SELECT 
    CASE 
        WHEN churn_flag = 1 THEN 'Churned (Inactive > 90 days)'
        WHEN total_spending > 5000 THEN 'VIP (High Spender)'
        WHEN total_orders > 10 THEN 'Loyal (Frequent)'
        ELSE 'Occasional'
    END AS customer_segment,
    COUNT(*) AS customer_count
FROM customer_behavior
GROUP BY 1;

-- 2.What is the average spending of a "Loyal" customer vs a "Churned" one?
SELECT 
    churn_flag, 
    AVG(total_spending) AS avg_lifetime_spend, 
    AVG(avg_order_value) AS avg_ticket_size
FROM customer_behavior
GROUP BY churn_flag;

