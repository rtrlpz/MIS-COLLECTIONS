-- ## Task 2 — Count January interactions by team ## --

/* 
Quick one: 
    - how many interactions did we make in January, 
    - per team? Sorted top-down. 
    - And if you have 30 seconds, per day too 
*/

-- a. Total January interactions
-- SELECT * FROM fact_interactions;
SELECT
	COUNT(*) AS "January Interactions" --Total_interactions
FROM fact_interactions AS fi
WHERE fi.interaction_date >= DATE '2025-01-01' 
	AND fi.interaction_date < DATE '2025-02-01';

-- b. January interactions per team
-- SELECT * FROM dim_employees;
-- SELECT * FROM fact_interactions; 
SELECT
	e.team_name AS "Team",
	COUNT(*) AS "Interactions"
FROM fact_interactions AS fi
JOIN dim_employees AS e
	ON fi.agent_id = e.agent_id
WHERE fi.interaction_date >= DATE '2025-01-01'
	AND fi.interaction_date < DATE '2025-02-01'
GROUP BY e.team_name
ORDER BY COUNT(*) DESC;

-- c. January interactions per day, chronological order. 
-- SELECT * FROM fact_interactions;
SELECT 
	fi.interaction_date AS "Date",
	COUNT(*) AS "Interactions"
FROM fact_interactions AS fi
WHERE fi.interaction_date >= DATE '2025-01-01' 
	AND fi.interaction_date < DATE '2025-02-01'
GROUP BY fi.interaction_date
ORDER BY fi.interaction_date;

-- Reconciliation check: sum of the team-level counts equals the January total.
-- Team Counts
WITH team_counts AS (
	SELECT
		e.team_name,
		COUNT(*) AS interactions
	FROM fact_interactions AS fi
	JOIN dim_employees AS e
		ON fi.agent_id = e.agent_id
	WHERE fi.interaction_date >= DATE '2025-01-01'
		AND fi.interaction_date < DATE '2025-02-01'
	GROUP BY e.team_name
)
SELECT 
	(SELECT COUNT(*)
	 FROM fact_interactions
	 WHERE interaction_date >= DATE '2025-01-01'
	 	AND interaction_date < DATE '2025-02-01'
	) AS overall_total, 
	SUM(interactions) AS total_from_teams, 
	(SELECT COUNT(*)
	 FROM fact_interactions
	 WHERE interaction_date >= DATE '2025-01-01'
	 	AND interaction_date < DATE '2025-02-01'
	) - SUM(interactions) AS difference
FROM team_counts;

-- Daily Counts
WITH daily_counts AS (
	SELECT 
		fi.interaction_date,
		COUNT (*) AS interactions
	FROM fact_interactions AS fi
	WHERE fi.interaction_date >= DATE '2025-01-01'
		AND fi.interaction_date < DATE '2025-02-01'
	GROUP BY fi.interaction_date
)
SELECT
	(SELECT COUNT(*)
	 FROM fact_interactions
	 WHERE interaction_date >= DATE '2025-01-01'
	 	AND interaction_date < DATE '2025-02-01'
	) AS overall_interactions, 
	SUM(interactions) AS total_from_days,
	(SELECT COUNT(*)
	 FROM fact_interactions
	 WHERE interaction_date >= DATE '2025-01-01'
	 	AND interaction_date < DATE '2025-02-01'
	) - SUM(interactions) AS difference
FROM daily_counts;

-- Reconciliation confirmed: team totals and daily totals both equal the
-- January interaction total; difference = 0.

/* 
Guiding questions: 
1. What makes your date filter safe if this column becomes a timestamp next year? 
   The filter uses a half-open date range: >= January 1 and < February 1.
   If interaction_date becomes a timestamp, it will include every record from
   January 1 at 00:00:00 through the end of January, without needing to specify
   the final time of day.
    
2. After joining to get team names, does the total still match step 1? 
   Confirm this by running the reconciliation query. If difference = 0, the
   sum of the team totals matches the overall January total.
	
3. If not, what leaked?
   If the joined total is lower, some interaction records did not find a
   matching employee through agent_id, so the INNER JOIN removed them.

   If the joined total is higher, the join created duplicate rows. This happens
   when one interaction matches more than one employee row, usually because
   the dimension join key is not unique or the wrong table was joined.
*/     
      
