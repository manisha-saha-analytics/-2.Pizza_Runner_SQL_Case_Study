----------------------------C.Ingredient Optimisation-----------------------------------------------

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

