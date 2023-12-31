
select * from sales
select * from members


-- Total Amount spent by each customer in restaurant--
SELECT s.customer_id, SUM(m.price) AS total_spent
FROM dbo.sales s
INNER JOIN dbo.menu m
ON s.product_id = m.product_id
GROUP BY s.customer_id;

--days each customer visited the restaurant--

SELECT s.customer_id, COUNT(DISTINCT s.order_date) AS days_visited
FROM dbo.sales s
GROUP BY s.customer_id;

--first item from the menu purchased by each customer--
WITH customer_first_purchase AS(
	SELECT s.customer_id, MIN( s.order_date) AS first_purchase_date
	FROM dbo.sales s
	GROUP BY s.customer_id
)
SELECT cfp.customer_id, cfp.first_purchase_date, m.product_name
FROM customer_first_purchase cfp
INNER JOIN dbo.sales s ON s.customer_id = cfp.customer_id
AND cfp.first_purchase_date = s.order_date
INNER JOIN dbo.menu m on m.product_id = s.product_id;

--Most Purchased item on the menu and the no of times the item is purchased
SELECT m.product_name,count(product_name) as times_purchased
FROM sales s
INNER JOIN menu m on s.product_id = m.product_id
group by m.product_name
order by times_purchased desc;

SELECT m.product_name, COUNT(*) AS total_purchased
FROM dbo.sales s
INNER JOIN dbo.menu m on s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY total_purchased DESC;

--Which item was the most popular for each customer?--
WITH customer_popularity AS (
    SELECT s.customer_id, m.product_name, COUNT(*) AS purchase_count,
        DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY COUNT(*) DESC) AS rank
    FROM sales s
    INNER JOIN menu m ON s.product_id = m.product_id
    GROUP BY s.customer_id, m.product_name
)
SELECT customer_id, product_name, purchase_count
FROM customer_popularity
WHERE rank = 1;

--Which item was purchased first by the customer after they became a member?--
WITH first_purchase_after_membership AS (
    SELECT s.customer_id, MIN(s.order_date) as first_purchase_date
    FROM dbo.sales s
    JOIN dbo.members mb ON s.customer_id = mb.customer_id
    WHERE s.order_date >= mb.join_date
    GROUP BY s.customer_id
)
SELECT fpam.customer_id, m.product_name
FROM first_purchase_after_membership fpam
JOIN dbo.sales s ON fpam.customer_id = s.customer_id 
AND fpam.first_purchase_date = s.order_date
JOIN dbo.menu m ON s.product_id = m.product_id;

--Which item was purchased just before the customer became a member?--

WITH last_purchase_before_membership AS (
    SELECT s.customer_id, MAX(s.order_date) AS last_purchase_date
    FROM dbo.sales s
    JOIN dbo.members mb ON s.customer_id = mb.customer_id
    WHERE s.order_date < mb.join_date
    GROUP BY s.customer_id
)
SELECT lpbm.customer_id, m.product_name
FROM last_purchase_before_membership lpbm
JOIN dbo.sales s ON lpbm.customer_id = s.customer_id 
AND lpbm.last_purchase_date = s.order_date
JOIN dbo.menu m ON s.product_id = m.product_id;

--The total items and amount spent for each member before they became a member--

SELECT s.customer_id, COUNT(*) as total_items, SUM(m.price) AS total_spent
FROM dbo.sales s
JOIN dbo.menu m ON s.product_id = m.product_id
JOIN dbo.members mb ON s.customer_id = mb.customer_id
WHERE s.order_date < mb.join_date
GROUP BY s.customer_id;

--If each $1 spent equates to 5 points and Biryani has a 2x points multiplier - how many points would each customer have?--

SELECT s.customer_id, SUM(
	CASE 
		WHEN m.product_name = 'Biryani' THEN m.price*10 
		ELSE m.price*5 END) AS total_points
FROM dbo.sales s
JOIN dbo.menu m ON s.product_id = m.product_id
GROUP BY s.customer_id;

/*In the first week after a customer joins the program (including their join date) 
they earn 2x points on all items, not just sushi - 
how many points do customer A and B have at the end of January?*/

SELECT s.customer_id, SUM(
    CASE 
        WHEN s.order_date BETWEEN mb.join_date AND DATEADD(day, 7, mb.join_date) THEN m.price*20
        WHEN m.product_name = 'sushi' THEN m.price*20 
        ELSE m.price*10 
    END) AS total_points
FROM dbo.sales s
JOIN dbo.menu m ON s.product_id = m.product_id
LEFT JOIN dbo.members mb ON s.customer_id = mb.customer_id
--WHERE s.customer_id IN ('A', 'B') AND s.order_date <= '2021-01-31'
WHERE s.customer_id = mb.customer_id AND s.order_date <= '2023-01-31'
GROUP BY s.customer_id;

--Recreating the table output using the available data--

SELECT s.customer_id, s.order_date, m.product_name, m.price,
CASE WHEN s.order_date >= mb.join_date THEN 'Y'
ELSE 'N' END AS member
FROM sales s
JOIN menu m ON s.product_id = m.product_id
LEFT JOIN members mb ON s.customer_id = mb.customer_id
ORDER BY s.customer_id, s.order_date;

--Ranking all the things
WITH customers_data AS (
	SELECT s.customer_id, s.order_date, m.product_name, m.price,
	CASE
		WHEN s.order_date < mb.join_date THEN 'N'
		WHEN s.order_date >= mb.join_date THEN 'Y'
		ELSE 'N' END AS member
	FROM sales s
	LEFT JOIN members mb ON s.customer_id = mb.customer_id
	JOIN menu m ON s.product_id = m.product_id
)
SELECT *,
CASE WHEN member = 'N' THEN NULL
ELSE RANK() OVER(PARTITION BY customer_id, member ORDER BY order_date)
END AS ranking
FROM customers_data
ORDER BY customer_id, order_date;