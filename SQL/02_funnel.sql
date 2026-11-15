-- =========================================
-- 2. Анализ воронки привлечения продавцов
-- Период заявок: 01.01.2018–31.05.2018
-- =========================================

-- 2.1. Конверсия заявки в договор
-- по маркетинговым каналам за 30 и 60 дней

SELECT COALESCE(NULLIF(TRIM(origin), ''), 'unknown') AS origin, COUNT(mql_id) as total_leads, 
COUNT(*) FILTER (
    WHERE won_date - first_contact_date BETWEEN 0 AND 30
) AS deals_30d,
ROUND(
(COUNT(*) FILTER (
    WHERE won_date - first_contact_date BETWEEN 0 AND 30
)) * 100.0 / COUNT(mql_id), 2) as CR_30d,
COUNT(*) FILTER (
    WHERE won_date - first_contact_date BETWEEN 0 AND 60
) AS deals_60d,
ROUND(
(COUNT(*) FILTER (
    WHERE won_date - first_contact_date BETWEEN 0 AND 60
)) * 100.0 / COUNT(mql_id), 2) as CR_60d
FROM marketing_qualified_leads
	LEFT JOIN closed_deals USING(mql_id)
WHERE first_contact_date >= '2018-01-01'
  AND first_contact_date < '2018-06-01'
GROUP BY 1
ORDER BY total_leads DESC;


--2.2 Сравнение 30-дневной конверсии
-- каналов привлечения с общей конверсией
-- Отклонения выражены в процентных пунктах
WITH channel_conversion AS (SELECT COALESCE(NULLIF(TRIM(origin), ''), 'unknown') AS origin, COUNT(mql_id) as total_leads, 
COUNT(*) FILTER (
    WHERE won_date - first_contact_date BETWEEN 0 AND 30
) AS deals_30d,
ROUND(
(COUNT(*) FILTER (
    WHERE won_date - first_contact_date BETWEEN 0 AND 30
)) * 100.0 / COUNT(mql_id), 2) as CR_30d,
COUNT(*) FILTER (
    WHERE won_date - first_contact_date BETWEEN 0 AND 60
) AS deals_60d,
ROUND(
(COUNT(*) FILTER (
    WHERE won_date - first_contact_date BETWEEN 0 AND 60
)) * 100.0 / COUNT(mql_id), 2) as CR_60d
FROM marketing_qualified_leads
	LEFT JOIN closed_deals USING(mql_id)
WHERE first_contact_date >= '2018-01-01'
  AND first_contact_date < '2018-06-01'
GROUP BY 1
ORDER BY total_leads DESC) 
SELECT origin, cr_30d, cr_30d - (
	SELECT ROUND(SUM(deals_30d) * 100.0 / SUM(total_leads), 2)
	FROM channel_conversion) as Отклонение_от_общей_CR
FROM channel_conversion
ORDER BY Отклонение_от_общей_CR DESC;