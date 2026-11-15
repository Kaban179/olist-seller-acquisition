--1.0 Проверка данных

--Проверка таблицы order_items
SELECT COUNT(order_id) AS number_order_items, COUNT(DISTINCT order_id) AS number_unique_orders,COUNT(DISTINCT seller_id) AS number_unique_sellers
FROM order_items;

--Проверка таблицы orders
SELECT COUNT(order_id) AS number_orders, COUNT(DISTINCT order_id) AS number_unique_orders, 
	MIN(order_purchase_timestamp) AS min_date_purchase, 
	MAX(order_purchase_timestamp) AS max_date_purchase
FROM orders;

--Проверка связи между таблицами двух датасетов
SELECT
    COUNT(DISTINCT closed_deals.seller_id) AS total_sellers,
    COUNT(DISTINCT order_items.seller_id) AS sellers_with_orders,
    COUNT(DISTINCT closed_deals.seller_id)
      - COUNT(DISTINCT order_items.seller_id) AS sellers_without_orders
FROM closed_deals
	LEFT JOIN order_items
	    ON closed_deals.seller_id = order_items.seller_id;

--Сколько продавцов имеют хотя бы один заказ после заключения договора
SELECT
    COUNT(DISTINCT order_items.seller_id) AS sellers_with_orders
FROM closed_deals
	LEFT JOIN order_items
	    ON closed_deals.seller_id = order_items.seller_id
	INNER JOIN orders USING(order_id)
WHERE order_purchase_timestamp >= won_date;

--Проверка заказов до договора
SELECT
    COUNT(DISTINCT order_items.seller_id) FILTER(WHERE order_purchase_timestamp >= won_date)AS sellers_with_orders_after_won,
    COUNT(DISTINCT order_items.seller_id) FILTER(WHERE order_purchase_timestamp < won_date)AS sellers_with_orders_before_won
FROM closed_deals
	LEFT JOIN order_items
	    ON closed_deals.seller_id = order_items.seller_id
	INNER JOIN orders USING(order_id);

--Проверка статусов заказов
SELECT
    order_status,
	COUNT(DISTINCT orders.order_id) FILTER(WHERE order_purchase_timestamp >= won_date) AS total_orders
FROM closed_deals
	LEFT JOIN order_items
	    ON closed_deals.seller_id = order_items.seller_id
	INNER JOIN orders USING(order_id)
GROUP BY order_status;

--Количество активированных продавцов
--(Активацией считаем первую продажу со статусов delivered)
SELECT COUNT(DISTINCT order_items.seller_id)
FROM closed_deals
	LEFT JOIN order_items
	    ON closed_deals.seller_id = order_items.seller_id
	INNER JOIN orders USING(order_id)
WHERE order_status = 'delivered'
AND order_purchase_timestamp >= won_date
AND order_purchase_timestamp < won_date + INTERVAL '30 days';

--какая доля продавцов, заключивших договор в течение 30 дней после заявки, начинает продавать товары в течение следующих 30 дней?
--Также сравнение по каналам привлечения

WITH cohort_sellers AS 
	(SELECT mql_id, seller_id, won_date, origin
	FROM marketing_qualified_leads
		LEFT JOIN closed_deals USING(mql_id)
	WHERE first_contact_date >= '2018-01-01' AND
		first_contact_date < '2018-06-01' AND
		won_date - first_contact_date BETWEEN 0 AND 30),
	pre_table AS 
	(SELECT COALESCE(NULLIF(TRIM(origin), ''), 'unknown') as origin, COUNT(DISTINCT cohort_sellers.seller_id) AS all_sellers, 
	COUNT(DISTINCT order_items.seller_id) FILTER (WHERE order_status = 'delivered'
		AND order_purchase_timestamp >= won_date
		AND order_purchase_timestamp < won_date + INTERVAL '30 days') as activated_sellers
	FROM cohort_sellers
		LEFT JOIN order_items
		    ON cohort_sellers.seller_id = order_items.seller_id
		LEFT JOIN orders USING(order_id)
	GROUP BY COALESCE(NULLIF(TRIM(origin), ''), 'unknown'))
SELECT origin, all_sellers, activated_sellers, activated_sellers * 100.0 / all_sellers AS activation_rate
FROM pre_table
ORDER BY 2 DESC ;


--Анализ конверсии заявок в активацию
WITH origin_leads_analysis AS
	(SELECT COALESCE(NULLIF(TRIM(origin), ''), 'unknown') AS origin, COUNT(mql_id) as total_leads
	FROM marketing_qualified_leads
		LEFT JOIN closed_deals USING(mql_id)
	WHERE first_contact_date >= '2018-01-01'
	  AND first_contact_date < '2018-06-01'
	GROUP BY 1
	),
	origin_sales_analysis AS 
	(WITH cohort_sellers AS 
	(SELECT mql_id, seller_id, won_date, origin
	FROM marketing_qualified_leads
		LEFT JOIN closed_deals USING(mql_id)
	WHERE first_contact_date >= '2018-01-01' AND
		first_contact_date < '2018-06-01' AND
		won_date - first_contact_date BETWEEN 0 AND 30),
	pre_table AS 
	(SELECT COALESCE(NULLIF(TRIM(origin), ''), 'unknown') as origin, COUNT(DISTINCT cohort_sellers.seller_id) AS all_sellers, 
	COUNT(DISTINCT order_items.seller_id) FILTER (WHERE order_status = 'delivered'
		AND order_purchase_timestamp >= won_date
		AND order_purchase_timestamp < won_date + INTERVAL '30 days') as activated_sellers
	FROM cohort_sellers
		LEFT JOIN order_items
		    ON cohort_sellers.seller_id = order_items.seller_id
		LEFT JOIN orders USING(order_id)
	GROUP BY COALESCE(NULLIF(TRIM(origin), ''), 'unknown'))
	SELECT origin, all_sellers, activated_sellers, activated_sellers * 100.0 / all_sellers AS activation_rate
	FROM pre_table)
SELECT
    origin,
    total_leads,
    COALESCE(activated_sellers, 0) AS activated_sellers,
    ROUND(
        COALESCE(activated_sellers, 0) * 100.0 / total_leads, 2) AS cr_lead_to_activation
FROM origin_leads_analysis LEFT JOIN origin_sales_analysis USING(origin)
ORDER BY 2 DESC;