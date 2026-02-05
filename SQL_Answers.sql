-- CS 527 Homework 1
-- Name: Chakradhar Reddy Punur
-- NetID: crp190

-- Question 1
WITH country_summary AS (
    SELECT
        country_code,
        COUNT(DISTINCT discipline) AS total_sports,
        COUNT(*) AS total_medals
    FROM medals
    GROUP BY country_code
),
top10 AS (
    SELECT *
    FROM country_summary
    ORDER BY total_sports DESC, total_medals DESC
    LIMIT 10
)
SELECT
    t.country_code AS COUNTRY,
    t.total_sports AS TOTAL_SPORTS,
    t.total_medals AS TOTAL_MEDALS,
    (
        SELECT GROUP_CONCAT(discipline || ': ' || medals_in_sport, ', ')
        FROM (
            SELECT discipline, COUNT(*) AS medals_in_sport
            FROM medals m
            WHERE m.country_code = t.country_code
            GROUP BY discipline
            ORDER BY medals_in_sport DESC, discipline ASC
        )
    ) AS MEDAL_DISTRIBUTION
FROM top10 t
ORDER BY t.total_sports DESC, t.total_medals DESC;

-- Question 2
WITH male_by_sport AS (
    SELECT
        country_code,
        discipline,
        COUNT(*) AS medals_in_sport
    FROM medals
    WHERE gender = 'M'
    GROUP BY country_code, discipline
),

male_totals AS (
    SELECT
        country_code,
        SUM(medals_in_sport) AS male_medals
    FROM male_by_sport
    GROUP BY country_code
),

male_ranked AS (
    SELECT
        country_code,
        male_medals,
        RANK() OVER (ORDER BY male_medals DESC) AS male_rank
    FROM male_totals
),

male_top_sport AS (
    SELECT country_code, discipline AS top_male_sport
    FROM (
        SELECT
            country_code,
            discipline,
            medals_in_sport,
            ROW_NUMBER() OVER (
                PARTITION BY country_code
                ORDER BY medals_in_sport DESC, discipline ASC
            ) AS rn
        FROM male_by_sport
    )
    WHERE rn = 1
),

female_by_sport AS (
    SELECT
        country_code,
        discipline,
        COUNT(*) AS medals_in_sport
    FROM medals
    WHERE gender = 'W'
    GROUP BY country_code, discipline
),

female_totals AS (
    SELECT
        country_code,
        SUM(medals_in_sport) AS female_medals
    FROM female_by_sport
    GROUP BY country_code
),

female_ranked AS (
    SELECT
        country_code,
        female_medals,
        RANK() OVER (ORDER BY female_medals DESC) AS female_rank
    FROM female_totals
),

female_top_sport AS (
    SELECT country_code, discipline AS top_female_sport
    FROM (
        SELECT
        country_code,
        discipline,
        medals_in_sport,
        ROW_NUMBER() OVER (
            PARTITION BY country_code
            ORDER BY medals_in_sport DESC, discipline ASC
        ) AS rn
        FROM female_by_sport
    )
    WHERE rn = 1
),

both_top10 AS (
    SELECT
        m.country_code,
        m.male_rank,
        f.female_rank,
        m.male_medals,
        f.female_medals
    FROM male_ranked m
    JOIN female_ranked f
    ON f.country_code = m.country_code
    WHERE m.male_rank <= 10
    AND f.female_rank <= 10
)

SELECT
    b.male_rank AS MALE_RANK,
    b.female_rank AS FEMALE_RANK,
    b.male_medals AS MALE_MEDALS,
    b.female_medals AS FEMALE_MEDALS,
    CASE
        WHEN b.male_medals > b.female_medals THEN 'Male'
        WHEN b.female_medals > b.male_medals THEN 'Female'
        ELSE 'Equal'
    END AS DOMINANT_GENDER,
    mts.top_male_sport    AS TOP_MALE_SPORT,
    fts.top_female_sport  AS TOP_FEMALE_SPORT
FROM both_top10 b
LEFT JOIN male_top_sport mts
ON mts.country_code = b.country_code
LEFT JOIN female_top_sport fts
ON fts.country_code = b.country_code
ORDER BY b.male_rank ASC, b.female_rank ASC;

-- Question 3
WITH athlete_ages AS (
	SELECT
		country_code,
		CAST ((julianday('2024-07-26') - julianday(birth_date)) / 365.25 AS REAL) AS age
	FROM athletes
	WHERE birth_date IS NOT NULL
),

age_stats AS (
	SELECT
		country_code,
		COUNT(*) AS num_athletes,
		AVG(age) AS avg_age,
		AVG(age * age) AS avg_age_sq
	FROM athlete_ages
	GROUP BY country_code
),

age_diversity AS (
	SELECT
		country_code,
		num_athletes,
		ROUND (
			SQRT(avg_age_sq - avg_age * avg_age),
			2
		) AS age_stddev
	FROM age_stats
),

medal_counts AS (
	SELECT
		country_code,
		COUNT(*) AS TOTAL_MEDALS
	FROM medals
	GROUP BY country_code
)

SELECT
	a.country_code AS COUNTRY,
	a.num_athletes AS NUM_ATHLETES,
	a.age_stddev AS AGE_STDDEV,
	COALESCE(m.total_medals, 0) AS TOTAL_MEDALS,
	ROUND(COALESCE(m.total_medals, 0) * 1.0 / a.num_athletes, 3) AS MEDALS_PER_ATHLETE
FROM age_diversity a
LEFT JOIN medal_counts m
ON m.country_code = a.country_code
ORDER BY AGE_STDDEV DESC;

-- Question 4
WITH medalist_heights AS (
	SELECT
		m.discipline,
		m.gender,
		a.height AS height_cm
	FROM medals m
	JOIN athletes a
	ON a.code = CAST(m.code AS INTEGER)
	WHERE a.height IS NOT NULL
    AND a.height > 0
),

binned AS (
	SELECT
		discipline,
		gender,
		height_cm,
		CAST(height_cm / 5 AS INTEGER) * 5 AS bin_start
	FROM medalist_heights
),

bin_counts AS (
	SELECT
		discipline,
		gender,
		bin_start,
		COUNT(*) AS medals_in_bin
	FROM binned
	GROUP BY discipline, gender, bin_start
),

ranked_bins AS (
	SELECT
		discipline,
		gender,
		bin_start,
		medals_in_bin,
		SUM(medals_in_bin) OVER (PARTITION BY discipline, gender) AS total_medals_in_dg,
		ROW_NUMBER() OVER (
			PARTITION BY discipline, gender
			ORDER BY medals_in_bin DESC, bin_start ASC
		) AS rn
	FROM bin_counts
),

avg_heights AS (
	SELECT
		discipline,
		gender,
		ROUND(AVG(height_cm), 1) AS avg_height_cm,
		COUNT(*) AS medal_count
	FROM medalist_heights
	GROUP BY discipline, gender
)

SELECT
	r.discipline AS DISCIPLINE,
	r.gender AS GENDER,
	a.avg_height_cm AS AVG_HEIGHT_CM,
	a.medal_count AS MEDAL_COUNT,
	(r.bin_start || '-' || (r.bin_start + 4)) AS IDEAL_HEIGHT_RANGE,
	ROUND(100.0 * r.medals_in_bin / r.total_medals_in_dg, 1) AS PCT_IN_IDEAL_RANGE
FROM ranked_bins r
JOIN avg_heights a
ON a.discipline = r.discipline
AND a.gender = r.gender
WHERE r.rn = 1
ORDER BY r.discipline ASC, r.gender ASC;

-- Question 5
WITH medals_per_athlete AS (
	SELECT 
		a.country_code,
		a.code AS athlete_code,
		a.name AS athlete_name,
		COUNT(*) AS medal_count
	FROM medals m
	JOIN athletes a
	ON CAST(a.code AS TEXT) = m.code
	WHERE m.code GLOB '[0-9]*' AND m.code <> ''
	GROUP BY a.country_code, a.code, a.name
),

total_medals_per_country AS (
	SELECT
		country_code,
		SUM(medal_count) AS total_medals,
		COUNT(*) AS unique_medalists
	FROM medals_per_athlete
	GROUP BY country_code
),

ranked_athletes_per_country AS (
	SELECT
		country_code,
		athlete_name,
		medal_count,
		ROW_NUMBER() OVER (
			PARTITION BY country_code
			ORDER BY medal_count DESC, athlete_name ASC
		) AS rn
	FROM medals_per_athlete
),

  top_athletes AS (
	SELECT
		country_code,
		SUM(CASE WHEN rn = 1 THEN medal_count ELSE 0 END) AS top_athlete_medals,
		SUM(CASE WHEN rn <= 3 THEN medal_count ELSE 0 END) AS top_3_athlete_medals,
		MAX(CASE WHEN rn = 1 THEN athlete_name END) AS most_decorated_athlete
	FROM ranked_athletes_per_country
	GROUP BY country_code
)

SELECT
	c.country_code AS COUNTRY,
	c.total_medals AS TOTAL_MEDALS,
	c.unique_medalists AS UNIQUE_MEDALISTS,
	ROUND (100.0 * t.top_3_athlete_medals / c.total_medals, 1) AS TOP_3_ATHLETES_SHARE,
	t.most_decorated_athlete AS MOST_DECORATED_ATHLETE,
	t.top_athlete_medals AS MEDAL_COUNT
FROM total_medals_per_country c
JOIN top_athletes t
ON t.country_code = c.country_code
ORDER BY TOP_3_ATHLETES_SHARE DESC, TOTAL_MEDALS DESC;
