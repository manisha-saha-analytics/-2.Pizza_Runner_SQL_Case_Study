						-------------A.Pizza Metrics-----------
--Q1.How many pizzas were ordered?

	SELECT COUNT(*) AS total_pizza_ordered
	FROM customer_orders;
	
--Q2. How many unique customers were made?

	SELECT COUNT(distinct customer_orders) AS unique_customer_oders
	FROM customer_orders;

--Q3.How many successful orders were delivered by each runner?

	SELECT runner_id,
	COUNT(order_id) AS successful_orders
	FROM runner_orders
	WHERE cancellation is null
	GROUP BY runner_id;

--Q4. How many of each type of pizza was delivered?

	SELECT p.pizza_name,
	COUNT(c.pizza_id) AS delivered_pizzas
	FROM customer_orders AS c

	INNER JOIN runner_orders as ro
	ON c.order_id = ro.order_id

	INNER JOIN pizza_names AS p
	ON c.pizza_id = p.pizza_id

	WHERE ro.cancellation IS NOT NULL

	GROUP BY p.pizza_name;

--Q5.How many vegetarian and Meatlovers were ordered by each customer?

	SELECT p.pizza_name,
	COUNT(c.pizza_id) AS delivered_pizzas
	FROM customer_orders AS c

	INNER JOIN pizza_names AS p 
	ON c.pizza_id = p.pizza_id

	GROUP BY c.customer_id, p.pizza_name

	ORDER BY c.customer_id;

--Q6. What was the maximum number of pizzas delivered in a single order?

	SELECT
  MAX(pizza_count) AS max_pizzas_per_order
FROM (
  SELECT
    order_id,
    COUNT(pizza_id) AS pizza_count
  FROM
    customer_orders
  GROUP BY
    order_id
) AS pizza_counts
JOIN (
  SELECT
    order_id
  FROM
    runner_orders
  WHERE
    cancellation IS NULL
) AS successful_orders
ON pizza_counts.order_id = successful_orders.order_id;

--Q7.For each customer, how many delivered pizzas had at least 1 change and how many had no changes?

	SELECT co.customer_id,
	SUM(
		CASE
			WHEN(exclusions IS NOT NULL AND exclusions != '0') OR (extras IS NOT NULL AND extras !='0') THEN 1
			Else 0
		END
		)AS pizza_with_changes,

	SUM(
		CASE
			WHEN(exclusions IS NULL AND exclusions = '0') OR (extras IS NULL AND extras = '0') THEN 1
			ELSE 0
		END
		)AS pizza_without_changes

	FROM customer_orders AS co

	INNER JOIN runner_orders AS ro
	ON co.order_id = ro.order_id

	WHERE ro.cancellation IS NULL
	
	GROUP BY
		co.customer_id;

--Q8. How many pizzas were delivered that had both exclusions and extras?

	SELECT
    COUNT(c.pizza_id) AS delivered_with_exclusions_and_extras
FROM
    customer_orders AS c
JOIN
    runner_orders AS r ON c.order_id = r.order_id
WHERE
    r.cancellation IS NULL AND c.exclusions IS NOT NULL AND c.extras IS NOT NULL;

--Q9. What was the total volume of pizzas ordered for each hour of the day?

 	SELECT EXTRACT(HOUR FROM order_time) AS hourly_data,
	 
	COUNT(order_id) AS Total_ordered_pizza
	
	FROM customer_orders

	GROUP BY
	hourly_data;

--Q10. What was the volume of orders for each day of the week?

	SELECT 
    TO_CHAR(order_time, 'Day') AS day_of_week,
    COUNT(order_id) AS total_orders
FROM customer_orders
GROUP BY TO_CHAR(order_time, 'Day')
ORDER BY total_orders DESC;


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



----------------------------C. Ingredient Optimisation-----------------------------------------------

--Q1. What are the standard ingredients for each pizza?

SELECT
    pn.pizza_name,
    STRING_AGG(pt.topping_name, ', ' ORDER BY pt.topping_name) AS standard_toppings
FROM
    pizza_names AS pn
JOIN
    pizza_recipes AS pr ON pn.pizza_id = pr.pizza_id
JOIN
    pizza_toppings AS pt ON pt.topping_id = ANY(string_to_array(pr.toppings, ',')::int[]) -- Corrected line
GROUP BY
    pn.pizza_name
ORDER BY
    pn.pizza_name;


--2.What was the most commonly added extra?

	WITH extra_toppings AS (
    SELECT
        unnest(string_to_array(extras, ',')) AS topping_id
    FROM
        customer_orders
    WHERE
        extras IS NOT NULL AND extras <> '' AND extras <> 'null'
)
SELECT
    pt.topping_name,
    COUNT(et.topping_id) AS extra_count
FROM
    extra_toppings AS et
JOIN
    pizza_toppings AS pt ON CAST(et.topping_id AS INTEGER) = pt.topping_id
GROUP BY
    pt.topping_name
ORDER BY
    extra_count DESC
LIMIT 1;


--Q3. What was the most common exclusion?

	WITH excluded_toppings AS (
    SELECT
        unnest(string_to_array(exclusions, ',')) AS topping_id
    FROM
        customer_orders
    WHERE
        exclusions IS NOT NULL AND exclusions <> '' AND exclusions <> 'null'
)
SELECT
    pt.topping_name,
    COUNT(et.topping_id) AS exclusion_count
FROM
    excluded_toppings AS et
JOIN
    pizza_toppings AS pt ON CAST(et.topping_id AS INTEGER) = pt.topping_id
GROUP BY
    pt.topping_name
ORDER BY
    exclusion_count DESC
LIMIT 1;

--Q4. Generate an order item for each record in the customers_orders table in the format of one of the following:
--Meat Lovers
--Meat Lovers - Exclude Beef
--Meat Lovers - Extra Bacon
--Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers.

WITH cleaned_orders AS (
    SELECT
        order_id,
        pizza_id,
        CASE WHEN exclusions IS NULL OR exclusions = '' OR exclusions = 'null' THEN NULL ELSE exclusions END AS exclusions_cleaned,
        CASE WHEN extras IS NULL OR extras = '' OR extras = 'null' THEN NULL ELSE extras END AS extras_cleaned
    FROM
        customer_orders
),
excluded_toppings_names AS (
    SELECT
        co.order_id,
        co.pizza_id,
        STRING_AGG(pt.topping_name, ', ' ORDER BY pt.topping_name) AS excluded_items
    FROM
        cleaned_orders AS co
    JOIN
        pizza_toppings AS pt ON pt.topping_id = ANY(string_to_array(co.exclusions_cleaned, ',')::int[])
    WHERE
        co.exclusions_cleaned IS NOT NULL
    GROUP BY
        co.order_id, co.pizza_id
),
extra_toppings_names AS (
    SELECT
        co.order_id,
        co.pizza_id,
        STRING_AGG(pt.topping_name, ', ' ORDER BY pt.topping_name) AS extra_items
    FROM
        cleaned_orders AS co
    JOIN
        pizza_toppings AS pt ON pt.topping_id = ANY(string_to_array(co.extras_cleaned, ',')::int[])
    WHERE
        co.extras_cleaned IS NOT NULL
    GROUP BY
        co.order_id, co.pizza_id
)
SELECT
    co.order_id,
    pn.pizza_name ||
    COALESCE(' - Exclude ' || etn.excluded_items, '') ||
    COALESCE(' - Extra ' || extn.extra_items, '') AS order_item
FROM
    cleaned_orders AS co
JOIN
    pizza_names AS pn ON co.pizza_id = pn.pizza_id
LEFT JOIN
    excluded_toppings_names AS etn ON co.order_id = etn.order_id AND co.pizza_id = etn.pizza_id
LEFT JOIN
    extra_toppings_names AS extn ON co.order_id = extn.order_id AND co.pizza_id = extn.pizza_id
ORDER BY
    co.order_id, co.pizza_id;

--Q5. Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
--For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"

WITH pizza_base_toppings AS (
    SELECT
        pn.pizza_id,
        pt.topping_id,
        pt.topping_name
    FROM
        pizza_names AS pn
    JOIN
        pizza_recipes AS pr ON pn.pizza_id = pr.pizza_id
    JOIN
        pizza_toppings AS pt ON pt.topping_id = ANY(string_to_array(pr.toppings, ',')::int[])
),
order_ingredients AS (
    SELECT
        co.order_id,
        co.customer_id,
        co.pizza_id,
        ptb.topping_name AS ingredient,
        -- Determine if the topping is an extra (2x) or a standard ingredient
        CASE
            WHEN string_to_array(co.extras, ',')::int[] @> ARRAY[ptb.topping_id] THEN '2x' || ptb.topping_name
            ELSE ptb.topping_name
        END AS formatted_ingredient,
        -- Flag to exclude ingredients
        CASE
            WHEN string_to_array(co.exclusions, ',')::int[] @> ARRAY[ptb.topping_id] THEN TRUE
            ELSE FALSE
        END AS is_excluded
    FROM
        customer_orders AS co
    JOIN
        pizza_base_toppings AS ptb ON co.pizza_id = ptb.pizza_id
    WHERE
        co.exclusions <> '' AND co.exclusions <> 'null' AND co.extras <> '' AND co.extras <> 'null'
)
SELECT
    oi.order_id,
    oi.customer_id,
    pn.pizza_name || ' : ' || STRING_AGG(oi.formatted_ingredient, ', ' ORDER BY oi.formatted_ingredient) AS ingredients_list
FROM
    order_ingredients AS oi
LEFT JOIN pizza_names AS pn
    ON oi.pizza_id = pn.pizza_id
WHERE
    NOT oi.is_excluded
GROUP BY
    oi.order_id, oi.customer_id, pn.pizza_name
ORDER BY
    oi.order_id, oi.customer_id;

--Q.6 What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?

WITH successful_orders AS (
    SELECT
        co.order_id,
        co.pizza_id,
        co.exclusions,
        co.extras
    FROM
        customer_orders co
    JOIN
        runner_orders ro ON co.order_id = ro.order_id
    WHERE
        ro.cancellation IS NULL OR ro.cancellation = '' OR ro.cancellation = 'null'
),
all_ingredients_per_order AS (
    SELECT
        so.order_id,
        so.pizza_id,
        unnest(string_to_array(pr.toppings, ',')) AS topping_id_str
    FROM
        successful_orders so
    JOIN
        pizza_recipes pr ON so.pizza_id = pr.pizza_id
    UNION ALL -- Include extras
    SELECT
        so.order_id,
        so.pizza_id,
        unnest(string_to_array(so.extras, ',')) AS topping_id_str
    FROM
        successful_orders so
    WHERE
        so.extras IS NOT NULL AND so.extras <> '' AND so.extras <> 'null'
),
final_ingredient_counts AS (
    SELECT
        ai.topping_id_str AS topping_id,
        COUNT(ai.topping_id_str) AS quantity
    FROM
        all_ingredients_per_order ai
    LEFT JOIN
        successful_orders so ON ai.order_id = so.order_id AND ai.pizza_id = so.pizza_id
    WHERE
        -- Exclude toppings if they are in the exclusions list for that order/pizza
        NOT (ai.topping_id_str = ANY(string_to_array(so.exclusions, ',')::text[])) OR so.exclusions IS NULL OR so.exclusions = '' OR so.exclusions = 'null'
    GROUP BY
        ai.topping_id_str
)
SELECT
    pt.topping_name,
    fic.quantity
FROM
    final_ingredient_counts fic
JOIN
    pizza_toppings pt ON CAST(fic.topping_id AS INTEGER) = pt.topping_id
ORDER BY
    fic.quantity DESC;


---------------------------D. Pricing and Ratings-----------------------------------

--Q1.If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes 
-- how much money has Pizza Runner made so far if there are no delivery fees?

SELECT 
	SUM(CASE
			WHEN pn.pizza_name = 'Meat Lovers' THEN 12
			WHEN pn.pizza_name = 'Vegetarian' THEN 10
			ELSE 0
			END) As total_revenue
	FROM customer_orders AS co

INNER JOIN runner_orders AS ro
ON co.order_id = ro.order_id

INNER JOIN pizza_names AS pn
ON co.pizza_id = pn.pizza_id

WHERE ro.cancellation IS NULL OR ro.cancellation = '' OR ro.cancellation ='null';

--Q2.What if there was an additional $1 charge for any pizza extras?
--Add cheese is $1 extras

WITH successful_orders AS(
	SELECT
		co.order_id,
		co.pizza_id,
		co.exclusions,
		CASE WHEN co.extras IS NULL OR co.extras = '' OR co.extras = 'null' THEN NULL END AS extras_cleaned
	FROM customer_orders AS co

	JOIN runner_orders as ro
	ON co.order_id = ro.order_id

	WHERE ro.cancellation IS NULL OR ro.cancellation = '' OR ro.cancellation = 'null'
),

extra_counts AS (
    SELECT
        so.order_id,
        so.pizza_id,
        CASE WHEN so.extras_cleaned IS NOT NULL THEN
            -- Count the number of extras by splitting the string and counting elements
            ARRAY_LENGTH(string_to_array(so.extras_cleaned, ','), 1)
        ELSE 0
        END AS num_extras
    FROM
        successful_orders so
)

SELECT
    SUM(CASE
        WHEN pn.pizza_name = 'Meatlovers' THEN 12
        WHEN pn.pizza_name = 'Vegetarian' THEN 10
        ELSE 0
    END) + SUM(ec.num_extras * 1) AS total_revenue_with_extras
FROM
    successful_orders AS so
JOIN
    pizza_names AS pn ON so.pizza_id = pn.pizza_id
LEFT JOIN -- Use LEFT JOIN since not all orders will have extras
    extra_counts AS ec ON so.order_id = ec.order_id AND so.pizza_id = ec.pizza_id;

--Q3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, 
--how would you design an additional table for this new dataset 
-- generate a schema for this new table and insert your own data for ratings 
--for each successful customer order between 1 to 5.

CREATE TABLE runner_ratings (
    rating_id SERIAL PRIMARY KEY,  
    order_id INTEGER NOT NULL,     
    runner_id INTEGER NOT NULL,    
    rating INTEGER NOT NULL,       
    rating_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
    comments TEXT                  
);

INSERT INTO runner_ratings (order_id, runner_id, rating, comments)
SELECT
    ro.order_id,
    ro.runner_id,
    CASE ro.order_id
        WHEN 1 THEN 4
        WHEN 2 THEN 5
        WHEN 3 THEN 3
        WHEN 4 THEN 2
        WHEN 5 THEN 5
        WHEN 7 THEN 4
        WHEN 8 THEN 1
        WHEN 10 THEN 3
        ELSE (random() * 4 + 1)::int -- Assign random ratings between 1 and 5
    END AS rating,
    CASE ro.order_id
        WHEN 1 THEN 'Fast delivery, driver was friendly.'
        WHEN 2 THEN 'Excellent service! Pizza was still hot.'
        WHEN 3 THEN 'A bit slow, but the pizza was correct.'
        WHEN 4 THEN 'Long wait, pizza was lukewarm.'
        WHEN 5 THEN 'Perfect in every way.'
        WHEN 7 THEN 'Good service, no issues.'
        WHEN 8 THEN 'Very disappointed with the delivery time.'
        WHEN 10 THEN 'Driver was polite, but delivery was average.'
        ELSE NULL
    END AS comments
FROM
    runner_orders AS ro
WHERE
    ro.cancellation IS NULL OR ro.cancellation = '' OR ro.cancellation = 'null'
ORDER BY
    ro.order_id;

--Q4.Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
--customer_id
--order_id
--runner_id
--rating
--order_time
--pickup_time
--Time between order and pickup
--Delivery duration
--Average speed
--Total number of pizzas

SELECT
    co.customer_id,
    co.order_id,
    ro.runner_id,
    rr.rating,
    co.order_time,
    CAST(ro.pickup_time AS TIMESTAMP) AS pickup_time, -- Convert to TIMESTAMP for calculations
    EXTRACT(EPOCH FROM (CAST(ro.pickup_time AS TIMESTAMP) - co.order_time)) / 60 AS time_between_order_and_pickup_minutes, -- Calculate in minutes
    CAST(REGEXP_REPLACE(ro.duration, '[^0-9]', '', 'g') AS INTEGER) AS delivery_duration_minutes, -- Clean and cast to INTEGER
    ROUND(
        (CAST(REGEXP_REPLACE(ro.distance, '[^0-9.]', '', 'g') AS DECIMAL(10,2)) / (CAST(REGEXP_REPLACE(ro.duration, '[^0-9]', '', 'g') AS INTEGER) / 60.0)),
        2
    ) AS average_speed_km_per_hour, -- Calculate and round average speed
    COUNT(co.pizza_id) AS total_number_of_pizzas -- Count pizzas for each order
FROM
    customer_orders AS co
JOIN
    runner_orders AS ro ON co.order_id = ro.order_id
JOIN
    runner_ratings AS rr ON co.order_id = rr.order_id AND ro.runner_id = rr.runner_id
WHERE
    ro.cancellation IS NULL OR ro.cancellation = '' OR ro.cancellation = 'null' -- Filter for successful deliveries
GROUP BY
    co.customer_id, co.order_id, ro.runner_id, rr.rating, co.order_time, ro.pickup_time, ro.distance, ro.duration -- Group by necessary columns for aggregation
ORDER BY
    co.order_id;

--Q5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled - how much money does Pizza Runner have left over after these deliveries?

WITH successful_pizza_costs AS (
    SELECT
        co.order_id,
        CASE
            WHEN pn.pizza_name = 'Meatlovers' THEN 12
            WHEN pn.pizza_name = 'Vegetarian' THEN 10
            ELSE 0
        END AS pizza_cost
    FROM
        customer_orders AS co
    JOIN
        runner_orders AS ro ON co.order_id = ro.order_id
    JOIN
        pizza_names AS pn ON co.pizza_id = pn.pizza_id
    WHERE
        ro.cancellation IS NULL OR ro.cancellation = '' OR ro.cancellation = 'null'
),
runner_fees AS (
    SELECT
        ro.order_id,
        CAST(REGEXP_REPLACE(ro.distance, '[^0-9.]', '', 'g') AS DECIMAL(10,2)) * 0.30 AS runner_fee
    FROM
        runner_orders AS ro
    WHERE
        ro.cancellation IS NULL OR ro.cancellation = '' OR ro.cancellation = 'null'
)
SELECT
    SUM(tpc.pizza_cost) - SUM(rf.runner_fee) AS money_left_over
FROM
    successful_pizza_costs AS tpc
LEFT JOIN
    runner_fees AS rf ON tpc.order_id = rf.order_id;



--------------------------E. BONUS QUESTION------------------------------------------

--Q. If Danny wants to expand his range of pizzas - 
--how would this impact the existing data design?
--Write an INSERT statement to demonstrate what would happen if a new Supreme pizza with all the toppings was added to the Pizza Runner menu?

INSERT INTO pizza_names (pizza_id, pizza_name)
VALUES (3, 'Supreme');

-- Insert the recipe (all existing toppings) into the pizza_recipes table
INSERT INTO pizza_recipes (pizza_id, toppings)
VALUES (3, '1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12');


