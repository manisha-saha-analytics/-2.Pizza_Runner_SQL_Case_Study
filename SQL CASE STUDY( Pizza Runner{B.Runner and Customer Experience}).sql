--------------------------B.Runner and Customer Experience-----------------------------

--Q1.How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)

SELECT 
	EXTRACT(WEEK FROM registration_date) AS registration_week,
	COUNT(runner_id) AS runner_count
	FROM runners
	GROUP BY registration_week;

--Q2.What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?

SELECT
    ro.runner_id,
    AVG(EXTRACT(EPOCH FROM (CAST(ro.pickup_time AS TIMESTAMP) - CAST(co.order_time AS TIMESTAMP))) / 60) 
	AS average_pickup_time_minutes
FROM
    customer_orders co
JOIN
    runner_orders ro
	ON co.order_id = ro.order_id
WHERE
    ro.pickup_time IS NOT NULL  -- Filter out orders that were not picked up (cancelled)
  
GROUP BY
    ro.runner_id
ORDER BY
    ro.runner_id;

--Q3.Is there any relationship between the number of pizzas and how long the order takes to prepare?

SELECT
    co.order_id,
    COUNT(co.pizza_id) AS number_of_pizzas,
    EXTRACT(EPOCH FROM (ro.pickup_time::timestamp - co.order_time)) / 60 AS preparation_time_minutes
FROM
    customer_orders co
JOIN
    runner_orders ro 
	ON co.order_id = ro.order_id
WHERE
    ro.pickup_time IS NOT NULL 
GROUP BY
    co.order_id, co.order_time, ro.pickup_time
ORDER BY
    number_of_pizzas, preparation_time_minutes;

--Q4.What was the average distance travelled for each customer?

SELECT
    co.customer_id,
    ROUND(AVG(CASE
        WHEN ro.distance LIKE '%km' THEN CAST(TRIM('km' FROM ro.distance) AS NUMERIC)
        ELSE CAST(ro.distance AS NUMERIC)
    END), 2) AS average_distance_km
FROM
    customer_orders co
JOIN
    runner_orders ro 
	ON co.order_id = ro.order_id
WHERE
    ro.distance IS NOT NULL
GROUP BY
    co.customer_id
ORDER BY
    co.customer_id;

--Q5.What was the difference between the longest and shortest delivery times for all orders?

WITH cleaned_durations AS (
    SELECT
        order_id,
        CAST(REGEXP_REPLACE(duration, '[^0-9]', '', 'g') AS INTEGER) AS duration_minutes
    FROM
        runner_orders
    WHERE
        pickup_time IS NOT NULL AND duration != 'null'
)
SELECT
    MAX(duration_minutes) - MIN(duration_minutes) AS difference_in_minutes
FROM
    cleaned_durations;

--Q6.What was the average speed for each runner for each delivery and do you notice any trend for these values?

WITH cleaned_data AS (
    SELECT
        runner_id,
        order_id,
        CAST(REGEXP_REPLACE(distance, '[^0-9.]', '', 'g') AS DECIMAL(10,2)) AS distance_km,
        CAST(REGEXP_REPLACE(duration, '[^0-9]', '', 'g') AS INTEGER) AS duration_minutes
    FROM
        runner_orders
    WHERE
        pickup_time IS NOT NULL AND duration != 'null' AND distance != 'null'
)
SELECT
    runner_id,
    order_id,
    distance_km,
    duration_minutes,
    ROUND((distance_km / (duration_minutes / 60.0)), 2) AS average_speed_km_per_hour
FROM
    cleaned_data
ORDER BY
    runner_id, order_id;

--Q7.What is the successful delivery percentage for each runner?

SELECT
    runner_id,
    ROUND( (SUM(CASE WHEN cancellation IS NULL OR cancellation = '' THEN 1 ELSE 0 END) * 100.0) / COUNT(order_id), 2) AS successful_delivery_percentage
FROM
    runner_orders
GROUP BY
    runner_id
ORDER BY
    runner_id;





	
