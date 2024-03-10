SELECT * FROM pitch LIMIT 100

SELECT * FROM raw_data LIMIT 10

SELECT DISTINCT release_spin_rate FROM pitch

ALTER TABLE pitch DROP COLUMN spin_dir

CREATE TABLE batter
(batter_id int PRIMARY KEY, batter_name text)

INSERT INTO batter
SELECT DISTINCT batter
FROM pitch

ALTER TABLE pitch
ADD CONSTRAINT fk_pitch_batter
FOREIGN KEY (batter) REFERENCES batter (batter_id)

SELECT DISTINCT fielder_2_1
FROM pitch
WHERE fielder_2_1
NOT IN (SELECT batter_id FROM batter)

CREATE TABLE player_ids_temp
(player_id int, player_name text)

SELECT * FROM player_ids_temp

UPDATE batter
SET batter_name = p.player_name
FROM player_ids_temp p
WHERE batter.batter_id = p.player_id;

-- validate success
SELECT * FROM batter;
-- did not work

-- some batter IDs that are missing
666452
703143
656029
501922
657017
573177
687493
622058
518782

SELECT * FROM player_ids_temp WHERE player_id = 518782;

SELECT * FROM batter WHERE batter_id = 547989;

SELECT * FROM batter WHERE batter_name IS NOT NULL;

SELECT *
FROM pitch p
JOIN batter b
ON p.batter = b.batter_id
WHERE b.batter_name IS NULL
AND pitch_type_id IS NOT NULL;

-- somehow have text in a numeric column
UPDATE pitch
SET release_spin_rate = NULL
WHERE release_spin_rate = 'NaN';

UPDATE pitch
SET spin_axis = NULL
WHERE spin_axis = 'NaN';

UPDATE pitch
SET release_extension = NULL
WHERE release_extension = 'NaN';

TRUNCATE player_ids_temp;

UPDATE batter
SET batter_name = p.player_name
FROM player_ids_temp p
WHERE batter.batter_id = p.player_id;

-- checking that all pitchers are accounted for
SELECT *
FROM pitch p
JOIN pitcher pp
ON p.pitcher = pp.pitcher_id
WHERE pp.name IS NULL
AND pitch_type_id IS NOT NULL;

SELECT COUNT(*) FROM pitch
WHERE pitch_type_id IS NOT NULL
--11.4 million pitches

-- ordering for time series
SELECT *
FROM pitch
WHERE pitch_type_id IS NOT NULL
AND pitcher_id = 136602
ORDER BY game_id, at_bat_number, pitch_number;

ALTER TABLE pitch
RENAME batter TO batter_id

SELECT * FROM pitcher WHERE pitcher_id = 136602

-- chart some metric of all pitches leading up to current atbat
-- average, weighted average, etc
-- chart specific pitches and movement/performance on those pitches
-- pitcher A has been throwing a slow curveball, batter A has been
-- hitting home runs on slow curveballs
-- chart trajectory/velocity of stats

SELECT * FROM play_event

-- data exploration
-- how many at-bats
SELECT COUNT(DISTINCT (game_id, at_bat_number))
FROM pitch;
-- 3,406,777 at-bats

-- how many of each outcome? i.e. number of home runs, singles, etc
SELECT description, COUNT(*)
FROM pitch p
JOIN play_event e
ON p.play_event_id = e.play_event_id
GROUP BY description
ORDER BY COUNT(*) DESC;

-- frequencies
"field_out"	1379642
"strikeout"	698820
"single"	506792
"walk"	268909
"double"	156050
"home_run"	96780
"force_out"	70510
"grounded_into_double_play"	66882
"hit_by_pitch"	33069
"field_error"	27441
"sac_fly"	22989
"sac_bunt"	18869
"triple"	16242
"intent_walk"	10161
"double_play"	8602
"fielders_choice"	6715
"fielders_choice_out"	5759
"caught_stealing_2b"	4181
"strikeout_double_play"	2664
"other_out"	643
"catcher_interf"	447
"sac_fly_double_play"	339
"pickoff_1b"	241
"caught_stealing_3b"	233
"caught_stealing_home"	124
"pickoff_2b"	106
"wild_pitch"	94
"triple_play"	75
"pickoff_caught_stealing_2b"	50
"pickoff_3b"	35
"pickoff_caught_stealing_3b"	34
"pickoff_caught_stealing_home"	26
"sac_bunt_double_play"	23
"stolen_base_2b"	19
"game_advisory"	13
"passed_ball"	11
"runner_double_play"	7
"stolen_base_3b"	7
"ejection"	5
"other_advance"	1
"pickoff_error_2b"	1
"pickoff_error_1b"	1
"stolen_base_home"	1
"error"	1
"pickoff_error_3b"	1

SELECT * 
FROM pitch
WHERE game_id = 233792
AND at_bat_number = 64

7
14
12
11
1

SELECT * FROM team WHERE team_id = 15

SELECT * FROM play_description

SELECT * FROM game WHERE game_id = 233792

ALTER TABLE game ADD COLUMN is_valid boolean DEFAULT False

UPDATE game
SET is_valid = True
WHERE game_id IN (
SELECT game_id
FROM pitch
GROUP BY game_id
HAVING COUNT(CASE WHEN pitch_type_id IS NULL THEN 1 END) = 0)

SELECT * 
FROM game 
WHERE home_team_id = 15
ORDER BY game_date

SELECT game_date, home_team_id, 
game_date - (LAG(game_date) OVER (PARTITION BY home_team_id ORDER BY game_date))
FROM game
WHERE home_team_id = 15
ORDER BY game_date