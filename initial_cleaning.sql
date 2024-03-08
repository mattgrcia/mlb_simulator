SELECT * FROM pitch LIMIT 100

SELECT * FROM raw_data LIMIT 10

SELECT DISTINCT release_spin_rate FROM pitch

ALTER TABLE pitch DROP COLUMN spin_dir

SELECT * FROM

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
FROM pitch LIMIT 5 p
JOIN pitcher pp
ON p.pitcher = pp.pitcher_id
LIMIT 10
WHERE pp.name IS NULL
AND pitch_type_id IS NOT NULL;