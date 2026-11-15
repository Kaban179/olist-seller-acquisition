--Посчитать GMV каждого продавца за первые 30 дней после договора.
WITH cohort_sellers AS 
	(SELECT mql_id, seller_id, won_date, COALESCE(NULLIF(TRIM(origin), ''), 'unknown') as origin
	FROM marketing_qualified_leads
		LEFT JOIN closed_deals USING(mql_id)
	WHERE first_contact_date >= '2018-01-01' AND
		first_contact_date < '2018-06-01' AND
		won_date - first_contact_date BETWEEN 0 AND 30),
	seller_gmv AS 
	(SELECT seller_id, origin, 
		COUNT(DISTINCT order_id) FILTER (WHERE order_status = 'delivered'
			AND order_purchase_timestamp >= won_date
			AND order_purchase_timestamp < won_date + INTERVAL '30 days') as orders_30d,
		COALESCE(SUM(price) FILTER (WHERE order_status = 'delivered'
			AND order_purchase_timestamp >= won_date
			AND order_purchase_timestamp < won_date + INTERVAL '30 days'), 0) as gmv_30d
	FROM cohort_sellers
		LEFT JOIN order_items USING(seller_id)
		LEFT JOIN orders USING(order_id)
	GROUP BY seller_id, origin)
SELECT origin, 
	COUNT(seller_id) FILTER (WHERE orders_30d > 0) as act_sellers,
	SUM(gmv_30d) as total_gmv, 
	ROUND(SUM(gmv_30d) / NULLIF(COUNT(seller_id) FILTER (WHERE orders_30d > 0), 0), 2) as gmv_per_activated_seller
FROM seller_gmv
GROUP BY origin
ORDER BY total_gmv DESC;


--Посчитать выручку с одной заявки
WITH channel_leads AS
	(SELECT COALESCE(NULLIF(TRIM(origin), ''), 'unknown') AS origin, COUNT(mql_id) as total_leads
	FROM marketing_qualified_leads
		LEFT JOIN closed_deals USING(mql_id)
	WHERE first_contact_date >= '2018-01-01'
	  AND first_contact_date < '2018-06-01'
	GROUP BY 1
	), 
	gmv_per_origin AS
		(WITH cohort_sellers AS 
		(SELECT mql_id, seller_id, won_date, COALESCE(NULLIF(TRIM(origin), ''), 'unknown') as origin
		FROM marketing_qualified_leads
			LEFT JOIN closed_deals USING(mql_id)
		WHERE first_contact_date >= '2018-01-01' AND
			first_contact_date < '2018-06-01' AND
			won_date - first_contact_date BETWEEN 0 AND 30),
		seller_gmv AS 
		(SELECT seller_id, origin, 
			COUNT(DISTINCT order_id) FILTER (WHERE order_status = 'delivered'
				AND order_purchase_timestamp >= won_date
				AND order_purchase_timestamp < won_date + INTERVAL '30 days') as orders_30d,
			COALESCE(SUM(price) FILTER (WHERE order_status = 'delivered'
				AND order_purchase_timestamp >= won_date
				AND order_purchase_timestamp < won_date + INTERVAL '30 days'), 0) as gmv_30d
		FROM cohort_sellers
			LEFT JOIN order_items USING(seller_id)
			LEFT JOIN orders USING(order_id)
		GROUP BY seller_id, origin)
	SELECT origin, 
		COUNT(seller_id) FILTER (WHERE orders_30d > 0) as act_sellers,
		SUM(gmv_30d) as total_gmv, 
		ROUND(SUM(gmv_30d) / NULLIF(COUNT(seller_id) FILTER (WHERE orders_30d > 0), 0), 2) as gmv_per_activated_seller
	FROM seller_gmv
	GROUP BY origin
	ORDER BY total_gmv DESC)
SELECT origin, COALESCE(ROUND(total_gmv / total_leads, 2), 0) as gmv_per_lead
FROM channel_leads
	LEFT JOIN gmv_per_origin USING(origin)
ORDER BY gmv_per_lead DESC;


--Анализ влияния крупных игроков
WITH cohort_sellers AS 
	(SELECT mql_id, seller_id, won_date, COALESCE(NULLIF(TRIM(origin), ''), 'unknown') as origin
	FROM marketing_qualified_leads
		LEFT JOIN closed_deals USING(mql_id)
	WHERE first_contact_date >= '2018-01-01' AND
		first_contact_date < '2018-06-01' AND
		won_date - first_contact_date BETWEEN 0 AND 30),
	seller_gmv AS 
	(
    SELECT
        cs.seller_id,
        cs.origin,
        COUNT(DISTINCT o.order_id) FILTER (
            WHERE o.order_status = 'delivered'
              AND o.order_purchase_timestamp >= cs.won_date
              AND o.order_purchase_timestamp < cs.won_date + INTERVAL '30 days'
        ) AS orders_30d,
        COALESCE(SUM(oi.price) FILTER (
            WHERE o.order_status = 'delivered'
              AND o.order_purchase_timestamp >= cs.won_date
              AND o.order_purchase_timestamp < cs.won_date + INTERVAL '30 days'
        ), 0) AS gmv_30d
    FROM cohort_sellers cs
    LEFT JOIN order_items oi ON cs.seller_id = oi.seller_id
    LEFT JOIN orders o ON oi.order_id = o.order_id
    GROUP BY cs.seller_id, cs.origin
	),
	ranked_sellers AS
	(SELECT seller_id, origin, gmv_30d, ROW_NUMBER() OVER(PARTITION BY origin ORDER BY gmv_30d  DESC) as seller_rank
	FROM seller_gmv)
SELECT
    origin,
    SUM(gmv_30d) AS total_gmv,
    MAX(gmv_30d) AS top1_gmv,
    ROUND(
        MAX(gmv_30d) * 100.0 /
        NULLIF(SUM(gmv_30d), 0), 2
    ) AS top1_share_pct,
    ROUND(
        SUM(gmv_30d) FILTER (WHERE seller_rank <= 3) * 100.0 /
        NULLIF(SUM(gmv_30d), 0), 2
    ) AS top3_share_pct
FROM ranked_sellers
GROUP BY origin
ORDER BY total_gmv DESC;


--Итоговая таблица по каналам
WITH channel_leads AS (
    SELECT
        COALESCE(NULLIF(TRIM(origin), ''), 'unknown') AS origin,
        COUNT(mql_id) AS total_leads,
        COUNT(*) FILTER (WHERE won_date - first_contact_date BETWEEN 0 AND 30) AS deals_30d
    FROM marketing_qualified_leads
    LEFT JOIN closed_deals USING (mql_id)
    WHERE first_contact_date >= '2018-01-01'
      AND first_contact_date < '2018-06-01'
    GROUP BY 1
),
cohort_sellers AS (
    SELECT
        seller_id,
        won_date,
        COALESCE(NULLIF(TRIM(origin), ''), 'unknown') AS origin
    FROM marketing_qualified_leads
    INNER JOIN closed_deals USING (mql_id)
    WHERE first_contact_date >= '2018-01-01'
      AND first_contact_date < '2018-06-01'
      AND won_date - first_contact_date BETWEEN 0 AND 30
),
seller_gmv AS (
    SELECT
        cs.seller_id,
        cs.origin,
        COUNT(DISTINCT o.order_id) FILTER (
            WHERE o.order_status = 'delivered'
              AND o.order_purchase_timestamp >= cs.won_date
              AND o.order_purchase_timestamp < cs.won_date + INTERVAL '30 days'
        ) AS orders_30d,
        COALESCE(SUM(oi.price) FILTER (
            WHERE o.order_status = 'delivered'
              AND o.order_purchase_timestamp >= cs.won_date
              AND o.order_purchase_timestamp < cs.won_date + INTERVAL '30 days'
        ), 0) AS gmv_30d
    FROM cohort_sellers cs
    LEFT JOIN order_items oi ON cs.seller_id = oi.seller_id
    LEFT JOIN orders o ON oi.order_id = o.order_id
    GROUP BY cs.seller_id, cs.origin
),
channel_gmv AS (
    SELECT
        origin,
        COUNT(*) FILTER (WHERE orders_30d > 0) AS activated_sellers,
        SUM(gmv_30d) AS total_gmv
    FROM seller_gmv
    GROUP BY origin
)
SELECT
    cl.origin,
    cl.total_leads,
    cl.deals_30d,
    ROUND(cl.deals_30d * 100.0 / cl.total_leads, 2) AS cr_lead_to_deal,
    COALESCE(cg.activated_sellers, 0) AS activated_sellers,
    ROUND(COALESCE(cg.activated_sellers, 0) * 100.0 / cl.total_leads, 2) AS cr_lead_to_activation,
    COALESCE(cg.total_gmv, 0) AS total_gmv,
    ROUND(COALESCE(cg.total_gmv, 0) / cl.total_leads, 2) AS gmv_per_lead
FROM channel_leads cl
LEFT JOIN channel_gmv cg ON cl.origin = cg.origin
ORDER BY gmv_per_lead DESC;
	


