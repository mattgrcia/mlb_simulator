-- add time zones
ALTER TABLE team
ADD COLUMN time_zone int DEFAULT 0 NOT NULL;

SELECT * FROM team;

-- 0 Pacific
-- 1 Mountain
-- 2 Central
-- 3 Eastern
-- in order to capture the time difference, e.g. Seattle is 3 hours "behind" NYC

-- days and time zone change since last game
-- 999 if first game of the season/no prior games recorded
WITH game_time_zones AS (
	SELECT game.*, time_zone 
	FROM game
	JOIN team
	ON game.home_team_id = team.team_id
),
all_games AS (
	SELECT game_id, home_team_id AS team_id, game_date, time_zone FROM game_time_zones
	UNION ALL
	SELECT game_id, away_team_id, game_date, time_zone FROM game_time_zones
)

SELECT game_id, game_date, team_id, 
COALESCE(game_date - (LAG(game_date) OVER (PARTITION BY team_id ORDER BY game_date)), 999) AS days_break,
COALESCE(time_zone - (LAG(time_zone) OVER (PARTITION BY team_id ORDER BY game_date)), 999) AS tz_change
FROM all_games;

-- days since last home game
-- 999 if first home game of the season/no prior games recorded
SELECT game_id, game_date, home_team_id, 
COALESCE(game_date - (LAG(game_date) OVER (PARTITION BY home_team_id ORDER BY game_date)), 999)
FROM game
ORDER BY game_date;

-- add game types
ALTER TABLE game
ADD COLUMN game_type_id int REFERENCES game_type(game_type_id)

UPDATE game
SET game_type_id = pitch.game_type_id
FROM pitch
WHERE game.game_id = pitch.game_id;

ALTER TABLE pitch
DROP COLUMN game_type_id;

-- check that we have all/most of the games from each season

SELECT 162*15;
-- 2430 regular season games each season

SELECT EXTRACT(YEAR FROM game_date), COUNT(*)
FROM game
WHERE game_type_id = 2
GROUP BY EXTRACT(YEAR FROM game_date)
ORDER BY EXTRACT(YEAR FROM game_date);

-- get humidity, wind, temperature, precipitation

