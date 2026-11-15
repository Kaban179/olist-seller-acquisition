-- =========================================
-- 1. Проверка качества данных
-- =========================================

-- 1. Проверка пропусков в marketing_qualified_leads
SELECT
    COUNT(*) - COUNT(mql_id) AS missing_mql_id,
    COUNT(*) - COUNT(first_contact_date) AS missing_first_contact_date,
    COUNT(*) - COUNT(landing_page_id) AS missing_landing_page_id,
    COUNT(*) - COUNT(origin) AS missing_origin
FROM marketing_qualified_leads;

--2. Проверка пропусков в closed_deals
SELECT
    COUNT(*) - COUNT(mql_id) AS missing_mql_id,
    COUNT(*) - COUNT(seller_id) AS missing_seller_id,
    COUNT(*) - COUNT(won_date) AS missing_won_date
FROM closed_deals;


--3. Первоначальный анализ 
SELECT MIN(won_date - first_contact_date) as min_period, MAX(won_date - first_contact_date) as max_period,
ROUND(AVG(won_date - first_contact_date), 2) as avg_period, 
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY won_date - first_contact_date) as med_period,
COUNT(*) FILTER (
    WHERE won_date - first_contact_date BETWEEN 0 AND 7
) AS deals_7d,
COUNT(*) FILTER (
    WHERE won_date - first_contact_date BETWEEN 0 AND 14
) AS deals_14d,
COUNT(*) FILTER (
    WHERE won_date - first_contact_date BETWEEN 0 AND 30
) AS deals_30d,
COUNT(*) FILTER (
    WHERE won_date - first_contact_date < 0
) AS invalid_deals
FROM marketing_qualified_leads
	INNER JOIN closed_deals USING(mql_id);
	
--4. Продвинутый анализ
SELECT 
ROUND(AVG(won_date - first_contact_date), 2) as avg_period, 
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY won_date - first_contact_date) as med_period,
COUNT(*) FILTER (
    WHERE won_date - first_contact_date BETWEEN 0 AND 30
) AS deals_30d,
COUNT(*) FILTER (
    WHERE won_date - first_contact_date BETWEEN 0 AND 60
) AS deals_60d,
COUNT(*) FILTER (
    WHERE won_date - first_contact_date BETWEEN 0 AND 90
) AS deals_90d
FROM marketing_qualified_leads
	INNER JOIN closed_deals USING(mql_id)	
WHERE won_date - first_contact_date >= 0;

--5. Вывод строки с отрицательной разницей
SELECT *
FROM marketing_qualified_leads
	INNER JOIN closed_deals USING(mql_id)	
WHERE won_date - first_contact_date < 0;

-- Проверка временного покрытия:
-- количество заявок и 30-дневная конверсия по месяцам

--6. 
SELECT DATE_TRUNC('month', first_contact_date) as month, COUNT(mql_id) as number_contacts, 
COUNT(*) FILTER (
    WHERE won_date - first_contact_date BETWEEN 0 AND 30
) AS deals_30d,
ROUND(
(COUNT(*) FILTER (
    WHERE won_date - first_contact_date BETWEEN 0 AND 30
)) * 100.0 / COUNT(mql_id), 2) as CR_30d
FROM marketing_qualified_leads
	LEFT JOIN closed_deals USING(mql_id)	
WHERE first_contact_date >= '2018-01-01'
  AND first_contact_date < '2018-06-01'
GROUP BY 1
ORDER BY month;