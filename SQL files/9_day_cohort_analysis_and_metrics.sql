-- Часть 1: Когортный анализ

-- Когортный анализ Retention Rate и Churn Rate по месяцам регистрации

WITH cohorts AS (
    SELECT 
        user_id,
        DATE_FORMAT(join_date, '%Y-%m') AS cohort_month
    FROM users
),
activity AS (
    SELECT 
        u.user_id,
        c.cohort_month,
        TIMESTAMPDIFF(MONTH, u.join_date, p.creation_date) AS months_since_registration
    FROM users u
    JOIN cohorts c ON u.user_id = c.user_id
    JOIN posts p ON u.user_id = p.user_id
),
initial_counts AS (
    SELECT 
        cohort_month,
        COUNT(DISTINCT user_id) AS initial_users
    FROM cohorts
    GROUP BY cohort_month
)

SELECT 
    a.cohort_month,
    a.months_since_registration,
    (COUNT(DISTINCT a.user_id) / i.initial_users) * 100 AS retention_rate,
     (1 - (COUNT(DISTINCT a.user_id) / i.initial_users)) * 100 AS churn_rate
FROM activity a
JOIN initial_counts i ON a.cohort_month = i.cohort_month
GROUP BY a.cohort_month, a.months_since_registration
ORDER BY a.cohort_month, a.months_since_registration;

-- Lifetime по когортам (интеграл от Retention)

WITH cohorts AS (
    SELECT 
        user_id,
        DATE_FORMAT(join_date, '%Y-%m') AS cohort_month
    FROM users
),
activity AS (
    SELECT 
        u.user_id,
        c.cohort_month,
        TIMESTAMPDIFF(MONTH, u.join_date, p.creation_date) AS months_since_registration
    FROM users u
    JOIN cohorts c ON u.user_id = c.user_id
    JOIN posts p ON u.user_id = p.user_id
),
initial_counts AS (
    SELECT 
        cohort_month,
        COUNT(DISTINCT user_id) AS initial_users
    FROM cohorts
    GROUP BY cohort_month
),
monthly_retention AS (
    SELECT 
        a.cohort_month,
        a.months_since_registration,
        (COUNT(DISTINCT a.user_id) / i.initial_users) AS retention_rate
    FROM activity a
    JOIN initial_counts i ON a.cohort_month = i.cohort_month
    GROUP BY a.cohort_month, a.months_since_registration
)

SELECT 
    cohort_month,
     CAST(SUM(retention_rate) AS DECIMAL(10, 3)) AS lifetime
FROM monthly_retention
GROUP BY cohort_month
ORDER BY cohort_month;

-- Часть 2: Продуктовые метрики

-- MAU (Monthly Active Users)

SELECT 
    DATE_FORMAT(creation_date, '%Y-%m') AS activity_month,
    COUNT(DISTINCT user_id) AS mau
FROM 
    posts
GROUP BY 
    activity_month
ORDER BY 
    activity_month;

-- DAU (Daily Active Users)

SELECT 
    DATE(creation_date) AS activity_date,
    COUNT(DISTINCT user_id) AS dau
FROM 
    posts
GROUP BY 
    activity_date
ORDER BY 
    activity_date;

-- Sticky Factor (среднее дневное значение DAU в рамках месяца)

WITH daily_active AS (
    SELECT 
        DATE(creation_date) AS activity_date,
        COUNT(DISTINCT user_id) AS dau
    FROM posts
    GROUP BY activity_date
),
monthly_active AS (
    SELECT 
        DATE_FORMAT(creation_date, '%Y-%m') AS activity_month,
        COUNT(DISTINCT user_id) AS mau
    FROM posts
    GROUP BY activity_month
)

SELECT 
    m.activity_month,
    ROUND(AVG(d.dau) / m.mau, 3) AS sticky_factor
FROM monthly_active m
JOIN daily_active d ON DATE_FORMAT(d.activity_date, '%Y-%m') = m.activity_month
GROUP BY m.activity_month;

-- Sticky Factor (сумма DAU по всем дням месяца / MAU)

WITH daily_active AS (
    SELECT 
        DATE(creation_date) AS activity_date,
        COUNT(DISTINCT user_id) AS dau
    FROM posts
    GROUP BY activity_date
),
monthly_active AS (
    SELECT 
        DATE_FORMAT(creation_date, '%Y-%m') AS activity_month,
        COUNT(DISTINCT user_id) AS mau
    FROM posts
    GROUP BY activity_month
)

SELECT 
    m.activity_month,
    ROUND(SUM(d.dau) / (COUNT(DISTINCT d.activity_date) * m.mau), 3) AS sticky_factor
FROM monthly_active m
JOIN daily_active d ON DATE_FORMAT(d.activity_date, '%Y-%m') = m.activity_month
GROUP BY m.activity_month;

-- Конверсия в покупку (Conversion Rate)

WITH user_activity AS (
    SELECT DISTINCT user_id
    FROM posts
)

SELECT 
    COUNT(DISTINCT p.user_id) / COUNT(DISTINCT u.user_id) * 100 AS conversion_rate
FROM user_activity u
LEFT JOIN purchases p ON u.user_id = p.user_id;

-- Часть 3: Финансовые метрики

-- ARPU, ARPPU, LTV (Lifetime Value)

WITH cohorts AS (
    SELECT 
        user_id,
        DATE_FORMAT(join_date, '%Y-%m') AS cohort_month
    FROM users
),
activity AS (
    SELECT 
        u.user_id,
        c.cohort_month,
        TIMESTAMPDIFF(MONTH, u.join_date, p.creation_date) AS months_since_registration
    FROM users u
    JOIN cohorts c ON u.user_id = c.user_id
    JOIN posts p ON u.user_id = p.user_id
),
initial_counts AS (
    SELECT 
        cohort_month,
        COUNT(DISTINCT user_id) AS initial_users
    FROM cohorts
    GROUP BY cohort_month
),
monthly_retention AS (
    SELECT 
        a.cohort_month,
        a.months_since_registration,
        (COUNT(DISTINCT a.user_id) / i.initial_users) AS retention_rate
    FROM activity a
    JOIN initial_counts i ON a.cohort_month = i.cohort_month
    GROUP BY a.cohort_month, a.months_since_registration
),
arpu AS (
    SELECT 
        DATE_FORMAT(purchase_date, '%Y-%m') AS month,
        SUM(amount) / COUNT(DISTINCT user_id) AS arpu
    FROM purchases
    GROUP BY month
),
arppu AS (
    SELECT 
        DATE_FORMAT(purchase_date, '%Y-%m') AS month,
        SUM(amount) / COUNT(DISTINCT user_id) AS arppu
    FROM purchases
    WHERE amount > 0
    GROUP BY month
),
lifetime AS (
    SELECT 
        cohort_month,
        SUM(retention_rate) AS lifetime
    FROM monthly_retention
    GROUP BY cohort_month
)

SELECT 
    arpu.month, 
	CAST(arpu.arpu AS DECIMAL(10, 0)) AS arpu,
    CAST(arppu.arppu AS DECIMAL(10, 0)) AS arppu,
    CAST(arpu.arpu * lifetime.lifetime AS DECIMAL(10, 2)) AS ltv
FROM arpu
JOIN lifetime ON arpu.month = lifetime.cohort_month
JOIN arppu ON arppu.month = lifetime.cohort_month;

-- ROI и ROMI

-- дополним таблицу marketing_spends колонкой с немаркетинговыми расходами

ALTER TABLE marketing_spends
ADD COLUMN other_expenses DECIMAL(10, 2) DEFAULT 0;

SET SQL_SAFE_UPDATES = 0;

UPDATE marketing_spends SET other_expenses = 600.00 WHERE month = '2008-01-01';
UPDATE marketing_spends SET other_expenses = 700.00 WHERE month = '2008-02-01';
UPDATE marketing_spends SET other_expenses = 800.00 WHERE month = '2008-03-01';
UPDATE marketing_spends SET other_expenses = 750.00 WHERE month = '2008-04-01';
UPDATE marketing_spends SET other_expenses = 680.00 WHERE month = '2008-05-01';
UPDATE marketing_spends SET other_expenses = 720.00 WHERE month = '2008-06-01';
UPDATE marketing_spends SET other_expenses = 650.00 WHERE month = '2008-07-01';
UPDATE marketing_spends SET other_expenses = 800.00 WHERE month = '2008-08-01';
UPDATE marketing_spends SET other_expenses = 780.00 WHERE month = '2008-09-01';
UPDATE marketing_spends SET other_expenses = 690.00 WHERE month = '2008-10-01';
UPDATE marketing_spends SET other_expenses = 730.00 WHERE month = '2008-11-01';
UPDATE marketing_spends SET other_expenses = 710.00 WHERE month = '2008-12-01';

SET SQL_SAFE_UPDATES = 1;

select * from marketing_spends;

-- считаем ROI и ROMI

SELECT 
    DATE_FORMAT(p.purchase_date, '%Y-%m') AS month,
    SUM(p.amount) AS total_revenue,
    SUM(m.spend) AS marketing_spend,
    SUM(m.other_expenses) AS other_expenses,
    -- Рассчитываем ROMI как (доход - маркетинговые расходы) / маркетинговые расходы
    ((SUM(p.amount) - SUM(m.spend)) / SUM(m.spend)) * 100 AS romi,
    -- Рассчитываем ROI как (доход - общие расходы) / общие расходы
    ((SUM(p.amount) - (SUM(m.spend) + SUM(m.other_expenses))) / (SUM(m.spend) + SUM(m.other_expenses))) * 100 AS roi
FROM 
    purchases p
JOIN 
    marketing_spends m ON DATE_FORMAT(p.purchase_date, '%Y-%m') = DATE_FORMAT(m.month, '%Y-%m')
GROUP BY 
    DATE_FORMAT(p.purchase_date, '%Y-%m');
    
-- Часть 4: Прогнозирование

-- Пример прогноза активности пользователей через 3-месячное скользящее среднее темпа роста

WITH user_growth AS (
    SELECT 
        DATE_FORMAT(join_date, '%Y-%m') AS month,
        COUNT(user_id) AS new_users,
        LAG(COUNT(user_id), 1) OVER (ORDER BY DATE_FORMAT(join_date, '%Y-%m')) AS prev_users
    FROM users
    GROUP BY month
),
growth_rate AS (
    SELECT 
        month, new_users,
        COALESCE((new_users - prev_users) / prev_users, 0) AS growth_rate
    FROM user_growth
)

SELECT 
    month, new_users,
    AVG(growth_rate) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_avg_growth
FROM 
    growth_rate;

-- теперь спрогнозируем количество новых пользователей в следующем месяце

WITH user_growth AS (
    SELECT 
        DATE_FORMAT(join_date, '%Y-%m') AS month,
        COUNT(user_id) AS new_users,
        LAG(COUNT(user_id), 1) OVER (ORDER BY DATE_FORMAT(join_date, '%Y-%m')) AS prev_users
    FROM users
    GROUP BY month
),
growth_rate AS (
    SELECT 
        month,
        new_users,
        COALESCE((new_users - prev_users) / prev_users, 0) AS growth_rate
    FROM user_growth
),
moving_avg_growth AS (
    SELECT 
        month,
        new_users,
        AVG(growth_rate) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_avg_growth
    FROM growth_rate
),
last_values AS (
    SELECT 
        month AS last_month,
        new_users AS last_new_users,
        moving_avg_growth AS avg_growth
    FROM 
        moving_avg_growth
    ORDER BY 
        month DESC
    LIMIT 1
)

-- Используем последнее значение среднего роста для прогноза
SELECT 
    last_month,
    last_new_users,
    avg_growth,
    ROUND(last_new_users * (1 + avg_growth), 0) AS predicted_new_users
FROM 
    last_values;


