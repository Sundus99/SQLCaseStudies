USE `danny's diner`;
CREATE TABLE sales (
  `customer_id` VARCHAR(1),
  `order_date` DATE,
  `product_id` INTEGER
);


INSERT INTO sales
  (`customer_id`, `order_date`, `product_id`)
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 

CREATE TABLE menu (
  `product_id` INTEGER,
  `product_name` VARCHAR(5),
  `price` INTEGER
);

INSERT INTO menu
  (`product_id`, `product_name`, `price`)
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  `customer_id` VARCHAR(1),
  `join_date` DATE
);

INSERT INTO members
  (`customer_id`, `join_date`)
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');

/* --------------------
   Case Study Questions
   --------------------*/
CREATE TEMPORARY TABLE agg_sales AS
SELECT s.customer_id, s.order_date, m.join_date, s.product_id, menu.product_name, menu.price
FROM sales AS s
LEFT JOIN members AS m
ON s.customer_id = m.customer_id
INNER JOIN menu
ON s.product_id = menu.product_id;

SELECT *
FROM agg_sales;

-- 1. What is the total amount each customer spent at the restaurant?
SELECT customer_id, SUM(price) AS total_amount
FROM agg_sales
GROUP BY customer_id;

-- 2. How many days has each customer visited the restaurant?
SELECT customer_id, COUNT(DISTINCT order_date)
FROM agg_sales
GROUP BY customer_id;

-- 3. What was the first item from the menu purchased by each customer?
SELECT customer_id, order_date, product_name
FROM agg_sales
ORDER BY order_date ASC
LIMIT 5;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT product_name, COUNT(product_name) AS num_times_purchased
FROM agg_sales
GROUP BY product_name
ORDER BY num_times_purchased DESC;

-- 5. Which item was the most popular for each customer?
WITH customer_sales AS (
SELECT customer_id, product_name, COUNT(product_name) AS num_times_purchased
FROM agg_sales
GROUP BY customer_id, product_name
)
SELECT customer_id, product_name, num_times_purchased, ranking
FROM (
	SELECT customer_id, product_name, num_times_purchased, RANK() OVER(PARTITION BY customer_id ORDER BY num_times_purchased DESC) AS ranking
    FROM customer_sales
) AS ranked_sales
WHERE ranking = 1;

-- 6. Which item was purchased first by the customer after they became a member?
-- EXPLAIN FORMAT = JSON
SELECT customer_id, order_date, join_date, product_name, ranking
FROM (
	SELECT customer_id, order_date, join_date, product_name, RANK() OVER(PARTITION BY customer_id ORDER BY order_date ASC) AS ranking
    FROM agg_sales
    WHERE order_date >= join_date
	) AS first_order
WHERE ranking = 1;

-- 7. Which item was purchased just before the customer became a member?
SELECT customer_id, order_date, join_date, product_name, ranking
FROM (
	SELECT customer_id, order_date, join_date, product_name, RANK() OVER(PARTITION BY customer_id ORDER BY order_date DESC) AS ranking
    FROM agg_sales
    WHERE order_date < join_date
) AS last_order
WHERE ranking = 1;

-- 8. What is the total items and amount spent for each member before they became a member?
SELECT customer_id, COUNT(PRODUCT_NAME) AS total_items, SUM(price) AS total_spent
FROM agg_sales
WHERE order_date < join_date
GROUP BY customer_id;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
WITH points_table AS(
	SELECT customer_id, product_name, price,
		CASE
			WHEN product_name = "sushi" THEN 2*10*price
			ELSE 10*price
		END AS points
	FROM agg_sales)
SELECT customer_id, SUM(points) AS total_points
FROM points_table
GROUP BY customer_id
ORDER BY total_points DESC;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items,  
--     not just sushi - how many points do customer A and B have at the end of January?
WITH days_calc AS(
	SELECT customer_id, product_name, price, order_date, join_date, MONTH(order_date) AS month,
		CASE
			WHEN order_date >= join_date THEN DATEDIFF(order_date,join_date)
			ELSE NULL
		END AS days_after_joining
	FROM agg_sales
)
SELECT customer_id, SUM(points) AS total_points
FROM(
	SELECT customer_id, product_name, price, days_after_joining,
		CASE
			WHEN days_after_joining >= 0 and days_after_joining <=7 THEN 2*10*price
            WHEN (days_after_joining > 7 or days_after_joining IS NULL) and product_name = "sushi" THEN 2*10*price
            ELSE 10*price
        END AS points
	FROM days_calc
    WHERE join_date IS NOT NULL and month = 1
) AS subquery
GROUP BY customer_id;