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
