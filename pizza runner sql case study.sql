
DROP TABLE IF EXISTS customer_orders;
CREATE TABLE customer_orders (
  "order_id" INTEGER,
  "customer_id" INTEGER,
  "pizza_id" INTEGER,
  "exclusions" VARCHAR(4),
  "extras" VARCHAR(4),
  "order_time" TIMESTAMP
);

INSERT INTO customer_orders
  ("order_id", "customer_id", "pizza_id", "exclusions", "extras", "order_time")
VALUES
  ('1', '101', '1', '', '', '2020-01-01 18:05:02'),
  ('2', '101', '1', '', '', '2020-01-01 19:00:52'),
  ('3', '102', '1', '', '', '2020-01-02 23:51:23'),
  ('3', '102', '2', '', NULL, '2020-01-02 23:51:23'),
  ('4', '103', '1', '4', '', '2020-01-04 13:23:46'),
  ('4', '103', '1', '4', '', '2020-01-04 13:23:46'),
  ('4', '103', '2', '4', '', '2020-01-04 13:23:46'),
  ('5', '104', '1', 'null', '1', '2020-01-08 21:00:29'),
  ('6', '101', '2', 'null', 'null', '2020-01-08 21:03:13'),
  ('7', '105', '2', 'null', '1', '2020-01-08 21:20:29'),
  ('8', '102', '1', 'null', 'null', '2020-01-09 23:54:33'),
  ('9', '103', '1', '4', '1, 5', '2020-01-10 11:22:59'),
  ('10', '104', '1', 'null', 'null', '2020-01-11 18:34:49'),
  ('10', '104', '1', '2, 6', '1, 4', '2020-01-11 18:34:49');


DROP TABLE IF EXISTS runner_orders;
CREATE TABLE runner_orders (
  "order_id" INTEGER,
  "runner_id" INTEGER,
  "pickup_time" VARCHAR(19),
  "distance" VARCHAR(7),
  "duration" VARCHAR(10),
  "cancellation" VARCHAR(23)
);

INSERT INTO runner_orders
  ("order_id", "runner_id", "pickup_time", "distance", "duration", "cancellation")
VALUES
  ('1', '1', '2020-01-01 18:15:34', '20km', '32 minutes', ''),
  ('2', '1', '2020-01-01 19:10:54', '20km', '27 minutes', ''),
  ('3', '1', '2020-01-03 00:12:37', '13.4km', '20 mins', NULL),
  ('4', '2', '2020-01-04 13:53:03', '23.4', '40', NULL),
  ('5', '3', '2020-01-08 21:10:57', '10', '15', NULL),
  ('6', '3', 'null', 'null', 'null', 'Restaurant Cancellation'),
  ('7', '2', '2020-01-08 21:30:45', '25km', '25mins', 'null'),
  ('8', '2', '2020-01-10 00:15:02', '23.4 km', '15 minute', 'null'),
  ('9', '2', 'null', 'null', 'null', 'Customer Cancellation'),
  ('10', '1', '2020-01-11 18:50:20', '10km', '10minutes', 'null');


DROP TABLE IF EXISTS pizza_names;
CREATE TABLE pizza_names (
  "pizza_id" INTEGER,
  "pizza_name" TEXT
);
INSERT INTO pizza_names
  ("pizza_id", "pizza_name")
VALUES
  (1, 'Meatlovers'),
  (2, 'Vegetarian');


DROP TABLE IF EXISTS pizza_recipes;
CREATE TABLE pizza_recipes (
  "pizza_id" INTEGER,
  "toppings" TEXT
);
INSERT INTO pizza_recipes
  ("pizza_id", "toppings")
VALUES
  (1, '1, 2, 3, 4, 5, 6, 8, 10'),
  (2, '4, 6, 7, 9, 11, 12');


DROP TABLE IF EXISTS pizza_toppings;
CREATE TABLE pizza_toppings (
  "topping_id" INTEGER,
  "topping_name" TEXT
);
INSERT INTO pizza_toppings
  ("topping_id", "topping_name")
VALUES
  (1, 'Bacon'),
  (2, 'BBQ Sauce'),
  (3, 'Beef'),
  (4, 'Cheese'),
  (5, 'Chicken'),
  (6, 'Mushrooms'),
  (7, 'Onions'),
  (8, 'Pepperoni'),
  (9, 'Peppers'),
  (10, 'Salami'),
  (11, 'Tomatoes'),
  (12, 'Tomato Sauce');

     --A.Pizza Metrics--
--Q1.How many pizzas were ordered?

SELECT COUNT(*) as total_pizza_orders
FROM customer_orders;

--Q2.How many unique customer orders were made?

SELECT COUNT(Distinct order_id) AS unique_customer_orders
FROM customer_orders;

--Q3.How many successful orders were delivered by each runner?

SELECT runner_id, COUNT(*) AS successful_orders
FROM runner_orders
Where cancellation IS NULL
GROUP BY runner_id;

--Q4.How many of each type of pizza was delivered?

SELECT c.pizza_id as delivered_pizzas
from customer_orders as c
inner join runner_orders as r
on c.order_id = r.order_id
where r.cancellation IS NULL
group by c.pizza_id;

--Q5.How many Vegetarian and Meatlovers were ordered by each customer?

Select co. customer_id, 
pn.pizza_name,
COUNT(*) as total_pizzas
from customer_orders as co
inner join pizza_names as pn
on co.pizza_id = pn.pizza_id
inner join runner_orders as ro
on co.order_id = ro.order_id
where ro.cancellation is null
group by co.customer_id, pn.pizza_name
order by co.customer_id, pn.pizza_name;

--Q6.What was the maximum number of pizzas were delivered in a single order?

SELECT MAX(pizza_count) AS max_pizzas_in_order
FROM(
	SELECT co.order_id, COUNT(*) AS pizza_count
	FROM customer_orders AS co
	INNER JOIN runner_orders AS ro
	ON co.order_id = ro.order_id
	WHERE ro.cancellation IS NULL
	GROUP BY co.order_id
) AS pizza_per_order;

--Q7.For each customer, how many delivered pizzas had at least one change,
--and how many had no changes?

SELECT co.customer_id,
COUNT(CASE
	WHEN (co.exclusions IS NOT NULL AND co.exclusions <> '')
	OR (co.extras IS NOT NULL AND co.extras <> '')
	THEN 1
	END) AS pizzas_with_changes,

COUNT(CASE
	WHEN (co.exclusions IS NOT NULL AND co.exclusions = '')
	OR (co.extras IS NOT NULL AND co.extras = '')
	THEN 1
	END) AS pizzas_without_changes

FROM customer_orders AS co
INNER JOIN runner_orders AS ro
ON co.order_id = ro.order_id
WHERE ro.cancellation IS NULL
GROUP BY co.customer_id
ORDER BY co.customer_id;

--Q8.How many pizzas were delivered that had both exclusions and extras?

SELECT COUNT(*) AS both_pizzas
FROM customer_orders AS co
INNER JOIN runner_orders AS ro
ON co.order_id = ro.order_id
WHERE ro.cancellation IS NULL
AND co.exclusions IS NOT NULL AND co.exclusions <> ''
AND co.extras IS NOT NULL AND co.extras <> '';

--Q9.What was the total volume of pizzas ordered for each hour of the day?

SELECT ro.runner_id,
COUNT(*) AS pizza_volume
FROM runner_orders as ro
INNER JOIN customer_orders AS co
ON ro.order_id = co.order_id
WHERE ro.cancellation IS NULL
GROUP BY ro.runner_id
ORDER BY ro.runner_id;

--Q.10 What was the volume of orders for each day of the week?

SELECT COUNT(*) AS pizza_runner_with_one_order
FROM(
	SELECT runner_id, COUNT(distinct order_id) as delivered_orders
	FROM runner_orders
	WHERE cancellation IS NULL
	GROUP BY runner_id
	HAVING COUNT(DISTINCT order_id) = 1
) AS single_order_runner;

