SELECT * FROM raw_data LIMIT 10

SELECT 
FROM raw_data 
GROUP BY game_date

-- create pitchers
CREATE TABLE pitcher (pitch_id int PRIMARY KEY, name text);
INSERT INTO pitcher
SELECT pitcher::int, player_name FROM raw_data
ON CONFLICT DO NOTHING;

SELECT * FROM pitcher;

SELECT COUNT(DISTINCT pitcher) FROM raw_data;

-- create pitches
CREATE TABLE pitch (pitch_id serial PRIMARY KEY, code text UNIQUE);

INSERT INTO pitch (code)
SELECT DISTINCT pitch_type
FROM raw_data
WHERE pitch_type <> 'NaN'
ON CONFLICT DO NOTHING;

SELECT * FROM pitch;

-- create events
CREATE TABLE play_event (play_event_id serial PRIMARY KEY, description text UNIQUE);

INSERT INTO play_event (description)
SELECT DISTINCT events
FROM raw_data
WHERE events <> 'NaN'
ON CONFLICT DO NOTHING;

SELECT * FROM play_event;

-- create descriptions
CREATE TABLE play_description (play_description_id serial PRIMARY KEY, description text UNIQUE);

INSERT INTO play_description (description)
SELECT DISTINCT description
FROM raw_data
WHERE description <> 'NaN'
ON CONFLICT DO NOTHING;

SELECT * FROM play_description;

-- game types
SELECT DISTINCT game_type FROM raw_data;
-- D,F,L,R,S,W

CREATE TABLE game_type (game_type_id serial PRIMARY KEY, description text UNIQUE);

INSERT INTO game_type (description)
SELECT DISTINCT game_type
FROM raw_data
WHERE game_type <> 'NaN'
ON CONFLICT DO NOTHING;

SELECT * FROM game_type;

-- pitcher handedness
SELECT DISTINCT p_throws FROM raw_data;
-- L,R

ALTER TABLE pitcher ADD COLUMN throws int;

-- inefficient update
UPDATE pitcher
SET throws = CASE WHEN raw_data.p_throws = 'R' THEN 0 ELSE 1 END
FROM raw_data
WHERE pitcher.pitcher_id = raw_data.pitcher::int;

-- hitter handedness
SELECT DISTINCT stand FROM raw_data;
-- L,R

-- teams
SELECT DISTINCT home_team FROM raw_data
UNION
SELECT DISTINCT away_team FROM raw_data;
-- 30 teams

CREATE TABLE team (team_id serial PRIMARY KEY, abbrev text UNIQUE);

INSERT INTO team (abbrev)
SELECT DISTINCT home_team FROM raw_data
UNION
SELECT DISTINCT away_team FROM raw_data
ON CONFLICT DO NOTHING;

SELECT * FROM team;

-- pitch result types
SELECT DISTINCT type FROM raw_data;
-- X (batted ball), S (strike), B (ball)
-- will use 0=B, 1=S, 2=X

-- batted ball types
SELECT DISTINCT bb_type FROM raw_data;
-- 0=fly_ball, 1=ground_ball, 2=line_drive, 3=popup

SELECT DISTINCT umpire FROM raw_data;
-- NaN, no umpire data collected

-- games
-- could be concerns here with uniqueness, would need to handle doubleheaders
-- so ignoring for now, hoping MLB had it right
CREATE TABLE game (game_id int PRIMARY KEY, 
				   game_date date,
				   home_team_id int REFERENCES team(team_id),
				   away_team_id int REFERENCES team(team_id));

-- as with all of these, could use DISTINCT instead of ON CONFLICT
-- thinking the latter has better efficiency
-- shouldn't be too noticeable at this small-ish scale
INSERT INTO game
SELECT game_pk::int,
game_date::date,
(SELECT team_id FROM team WHERE abbrev = home_team),
(SELECT team_id FROM team WHERE abbrev = away_team)
FROM raw_data
ON CONFLICT DO NOTHING;

-- forgot to make these non-null columns
ALTER TABLE game
ALTER COLUMN game_date
SET NOT NULL;

ALTER TABLE game
ALTER COLUMN home_team_id
SET NOT NULL;

ALTER TABLE game
ALTER COLUMN away_team_id
SET NOT NULL;

ALTER TABLE pitch_type RENAME pitch_id TO pitch_type_id;

-- first attempt at clean table
SELECT
-- identifiers for at-bat
game_pk::int,
at_bat_number::int,
pitch_number::int,
--situation
(SELECT game_type_id FROM game_type WHERE description = game_type),
pitcher::int,
batter::int,
CASE inning_topbot 
	WHEN 'Top' THEN 1 
	WHEN 'Bot' THEN 0 
	ELSE NULL 
END AS topbot,
outs_when_up::int,
home_score::int,
away_score::int,
inning::int,
balls::int,
strikes::int,
CASE on_1b
	WHEN 'NaN' THEN NULL
	ELSE on_1b::numeric::int
END AS on_1b,
CASE on_2b
	WHEN 'NaN' THEN NULL
	ELSE on_2b::numeric::int
END AS on_2b,
CASE on_3b
	WHEN 'NaN' THEN NULL
	ELSE on_3b::numeric::int
END AS on_3b,
CASE if_fielding_alignment
	WHEN 'Standard' THEN 0
	WHEN 'Strategic' THEN 1
	WHEN 'Infield shade' THEN 2
	WHEN 'Infield shift' THEN 3
	ELSE NULL 
END AS if_fielding_alignment,
CASE of_fielding_alignment
	WHEN 'Standard' THEN 0
	WHEN 'Strategic' THEN 1
	WHEN '4th outfielder' THEN 2
	WHEN 'Extreme outfield shift' THEN 3
	ELSE NULL 
END AS of_fielding_alignment,
fielder_2_1::int,
fielder_3::int,
fielder_4::int,
fielder_5::int,
fielder_6::int,
fielder_7::int,
fielder_8::int,
fielder_9::int,
CASE stand
	WHEN 'R' THEN 0
	WHEN 'L' THEN 1
	ELSE NULL
END as stand,
-- pitch data
(SELECT pitch_id FROM pitch WHERE description = pitch_type) AS pitch_id,
CASE release_speed
	WHEN 'NaN' THEN NULL
	ELSE release_speed::numeric
END AS release_speed,
CASE release_pos_x
	WHEN 'NaN' THEN NULL
	ELSE release_pos_x::numeric
END AS release_pos_x,
CASE release_pos_y
	WHEN 'NaN' THEN NULL
	ELSE release_pos_y::numeric
END AS release_pos_y,
CASE spin_dir
	WHEN 'NaN' THEN NULL
	ELSE spin_dir::numeric
END AS spin_dir,
CASE zone
	WHEN 'NaN' THEN NULL
	ELSE zone::numeric::int
END AS zone,
CASE pfx_x
	WHEN 'NaN' THEN NULL
	ELSE pfx_x::numeric
END AS pfx_x,
CASE pfx_z
	WHEN 'NaN' THEN NULL
	ELSE pfx_z::numeric
END AS pfx_z,
CASE plate_x
	WHEN 'NaN' THEN NULL
	ELSE plate_x::numeric
END AS plate_x,
CASE plate_z
	WHEN 'NaN' THEN NULL
	ELSE plate_z::numeric
END AS plate_z,
CASE hc_x
	WHEN 'NaN' THEN NULL
	ELSE hc_x::numeric
END AS hc_x,
CASE hc_y
	WHEN 'NaN' THEN NULL
	ELSE hc_y::numeric
END AS hc_y,
CASE vx0
	WHEN 'NaN' THEN NULL
	ELSE vx0::numeric
END AS vx0,
CASE vy0
	WHEN 'NaN' THEN NULL
	ELSE vy0::numeric
END AS vy0,
CASE vz0
	WHEN 'NaN' THEN NULL
	ELSE vz0::numeric
END AS vz0,
CASE ax
	WHEN 'NaN' THEN NULL
	ELSE ax::numeric
END AS ax,
CASE ay
	WHEN 'NaN' THEN NULL
	ELSE ay::numeric
END AS ay,
CASE az
	WHEN 'NaN' THEN NULL
	ELSE az::numeric
END AS az,
CASE sz_top
	WHEN 'NaN' THEN NULL
	ELSE sz_top::numeric
END AS sz_top,
CASE sz_bot
	WHEN 'NaN' THEN NULL
	ELSE sz_bot::numeric
END AS sz_bot,
CASE type
	WHEN 'B' THEN 0
	WHEN 'S' THEN 1
	WHEN 'X' THEN 2
	ELSE NULL
END AS pitch_outcome_type,
release_spin_rate::numeric,
release_extension::numeric,
spin_axis::numeric,
-- outcome
(SELECT play_event_id FROM play_event WHERE description = events) AS play_event_id,
(SELECT play_description_id FROM play_description WHERE description = raw_data.description) AS play_description_id,
CASE hit_location
	WHEN 'NaN' THEN NULL
	ELSE hit_location::numeric::int
END AS hit_location,
CASE bb_type
	WHEN 'fly_ball' THEN 0
	WHEN 'ground_ball' THEN 1
	WHEN 'line_drive' THEN 2
	WHEN 'popup' THEN 2
	ELSE NULL
END AS bb_type,
CASE hit_distance_sc
	WHEN 'NaN' THEN NULL
	ELSE hit_distance_sc::numeric
END AS hit_distance_sc,
CASE launch_speed
	WHEN 'NaN' THEN NULL
	ELSE launch_speed::numeric
END AS launch_speed,
CASE launch_angle
	WHEN 'NaN' THEN NULL
	ELSE launch_angle::numeric
END AS launch_angle,
CASE effective_speed
	WHEN 'NaN' THEN NULL
	ELSE effective_speed::numeric
END AS effective_speed,
CASE estimated_ba_using_speedangle
	WHEN 'NaN' THEN NULL
	ELSE estimated_ba_using_speedangle::numeric
END AS estimated_ba_using_speedangle,
CASE estimated_woba_using_speedangle
	WHEN 'NaN' THEN NULL
	ELSE estimated_woba_using_speedangle::numeric
END AS estimated_woba_using_speedangle,
CASE woba_value
	WHEN 'NaN' THEN NULL
	ELSE woba_value::numeric
END AS woba_value,
CASE woba_denom
	WHEN 'NaN' THEN NULL
	ELSE woba_denom::numeric
END AS woba_denom,
CASE babip_value
	WHEN 'NaN' THEN NULL
	ELSE babip_value::numeric
END AS babip_value,
CASE iso_value
	WHEN 'NaN' THEN NULL
	ELSE iso_value::numeric
END AS iso_value,
CASE launch_speed_angle
	WHEN 'NaN' THEN NULL
	ELSE launch_speed_angle::numeric
END AS launch_speed_angle,
CASE delta_home_win_exp
	WHEN 'NaN' THEN NULL
	ELSE delta_home_win_exp::numeric
END AS delta_home_win_exp,
CASE delta_run_exp
	WHEN 'NaN' THEN NULL
	ELSE delta_run_exp::numeric
END AS delta_run_exp,
post_home_score::numeric,
post_away_score::int
FROM raw_data;

SELECT DISTINCT spin_rate_deprecated from raw_data;
-- just NaN

SELECT DISTINCT break_angle_deprecated from raw_data;
-- just NaN

SELECT DISTINCT break_length_deprecated from raw_data;
-- just NaN

SELECT DISTINCT tfs_deprecated from raw_data;
-- just NaN

SELECT DISTINCT tfs_zulu_deprecated from raw_data;
-- just NaN


CREATE TABLE pitch (
	game_id int REFERENCES game(game_id) NOT NULL,
	at_bat_number int NOT NULL,
pitch_number int NOT NULL,
game_type_id int REFERENCES game_type(game_type_id),
pitcher int REFERENCES pitcher(pitcher_id) NOT NULL,
batter int NOT NULL,
inning_topbot int NOT NULL,
outs_when_up int NOT NULL,
home_score int NOT NULL,
away_score int NOT NULL,
inning int NOT NULL,
balls int NOT NULL,
strikes int NOT NULL,
on_1b int,
on_2b int,
on_3b int,
if_fielding_alignment int,
of_fielding_alignment int,
fielder_2_1 int,
fielder_3 int,
fielder_4 int,
fielder_5 int,
fielder_6 int,
fielder_7 int,
fielder_8 int,
fielder_9 int,
stand int,
pitch_type_id int REFERENCES pitch_type(pitch_type_id),
release_speed numeric,
release_pos_x numeric,
release_pos_y numeric,
spin_dir numeric,
zone int,
pfx_x numeric,
 pfx_z numeric,
plate_x numeric,
plate_z numeric,
hc_x numeric,
hc_y numeric,
vx0 numeric,
vy0 numeric,
vz0 numeric,
ax numeric,
ay numeric,
az numeric,
sz_top numeric,
sz_bot numeric,
pitch_outcome_type int,
release_spin_rate numeric,
release_extension numeric,
spin_axis numeric,
play_event_id int REFERENCES play_event(play_event_id),
play_description_id int REFERENCES play_description(play_description_id),
hit_location int,
bb_type int,
hit_distance_sc numeric,
launch_speed numeric,
launch_angle numeric,
effective_speed numeric,
estimated_ba_using_speedangle numeric,
estimated_woba_using_speedangle numeric,
woba_value numeric,
woba_denom numeric,
babip_value numeric,
iso_value numeric,
launch_speed_angle numeric,
delta_home_win_exp numeric,
delta_run_exp numeric,
post_home_score numeric,
post_away_score int,
PRIMARY KEY (game_id, at_bat_number, pitch_number)
);


INSERT INTO pitch
SELECT
-- identifiers for at-bat
game_pk::int,
at_bat_number::int,
pitch_number::int,
--situation
(SELECT game_type_id FROM game_type WHERE description = raw_data.game_type),
pitcher::int,
batter::int,
CASE inning_topbot 
	WHEN 'Top' THEN 1 
	WHEN 'Bot' THEN 0 
	ELSE NULL 
END AS topbot,
outs_when_up::int,
home_score::int,
away_score::int,
inning::int,
balls::int,
strikes::int,
CASE on_1b
	WHEN 'NaN' THEN NULL
	ELSE on_1b::numeric::int
END AS on_1b,
CASE on_2b
	WHEN 'NaN' THEN NULL
	ELSE on_2b::numeric::int
END AS on_2b,
CASE on_3b
	WHEN 'NaN' THEN NULL
	ELSE on_3b::numeric::int
END AS on_3b,
CASE if_fielding_alignment
	WHEN 'Standard' THEN 0
	WHEN 'Strategic' THEN 1
	WHEN 'Infield shade' THEN 2
	WHEN 'Infield shift' THEN 3
	ELSE NULL 
END AS if_fielding_alignment,
CASE of_fielding_alignment
	WHEN 'Standard' THEN 0
	WHEN 'Strategic' THEN 1
	WHEN '4th outfielder' THEN 2
	WHEN 'Extreme outfield shift' THEN 3
	ELSE NULL 
END AS of_fielding_alignment,
fielder_2_1::int,
fielder_3::int,
fielder_4::int,
fielder_5::int,
fielder_6::int,
fielder_7::int,
fielder_8::int,
fielder_9::int,
CASE stand
	WHEN 'R' THEN 0
	WHEN 'L' THEN 1
	ELSE NULL
END as stand,
-- pitch data
(SELECT pitch_type_id FROM pitch_type WHERE code = raw_data.pitch_type) AS pitch_type_id,
CASE release_speed
	WHEN 'NaN' THEN NULL
	ELSE release_speed::numeric
END AS release_speed,
CASE release_pos_x
	WHEN 'NaN' THEN NULL
	ELSE release_pos_x::numeric
END AS release_pos_x,
CASE release_pos_y
	WHEN 'NaN' THEN NULL
	ELSE release_pos_y::numeric
END AS release_pos_y,
CASE spin_dir
	WHEN 'NaN' THEN NULL
	ELSE spin_dir::numeric
END AS spin_dir,
CASE zone
	WHEN 'NaN' THEN NULL
	ELSE zone::numeric::int
END AS zone,
CASE pfx_x
	WHEN 'NaN' THEN NULL
	ELSE pfx_x::numeric
END AS pfx_x,
CASE pfx_z
	WHEN 'NaN' THEN NULL
	ELSE pfx_z::numeric
END AS pfx_z,
CASE plate_x
	WHEN 'NaN' THEN NULL
	ELSE plate_x::numeric
END AS plate_x,
CASE plate_z
	WHEN 'NaN' THEN NULL
	ELSE plate_z::numeric
END AS plate_z,
CASE hc_x
	WHEN 'NaN' THEN NULL
	ELSE hc_x::numeric
END AS hc_x,
CASE hc_y
	WHEN 'NaN' THEN NULL
	ELSE hc_y::numeric
END AS hc_y,
CASE vx0
	WHEN 'NaN' THEN NULL
	ELSE vx0::numeric
END AS vx0,
CASE vy0
	WHEN 'NaN' THEN NULL
	ELSE vy0::numeric
END AS vy0,
CASE vz0
	WHEN 'NaN' THEN NULL
	ELSE vz0::numeric
END AS vz0,
CASE ax
	WHEN 'NaN' THEN NULL
	ELSE ax::numeric
END AS ax,
CASE ay
	WHEN 'NaN' THEN NULL
	ELSE ay::numeric
END AS ay,
CASE az
	WHEN 'NaN' THEN NULL
	ELSE az::numeric
END AS az,
CASE sz_top
	WHEN 'NaN' THEN NULL
	ELSE sz_top::numeric
END AS sz_top,
CASE sz_bot
	WHEN 'NaN' THEN NULL
	ELSE sz_bot::numeric
END AS sz_bot,
CASE type
	WHEN 'B' THEN 0
	WHEN 'S' THEN 1
	WHEN 'X' THEN 2
	ELSE NULL
END AS pitch_outcome_type,
release_spin_rate::numeric,
release_extension::numeric,
spin_axis::numeric,
-- outcome
(SELECT play_event_id FROM play_event WHERE description = events) AS play_event_id,
(SELECT play_description_id FROM play_description WHERE description = raw_data.description) AS play_description_id,
CASE hit_location
	WHEN 'NaN' THEN NULL
	ELSE hit_location::numeric::int
END AS hit_location,
CASE bb_type
	WHEN 'fly_ball' THEN 0
	WHEN 'ground_ball' THEN 1
	WHEN 'line_drive' THEN 2
	WHEN 'popup' THEN 2
	ELSE NULL
END AS bb_type,
CASE hit_distance_sc
	WHEN 'NaN' THEN NULL
	ELSE hit_distance_sc::numeric
END AS hit_distance_sc,
CASE launch_speed
	WHEN 'NaN' THEN NULL
	ELSE launch_speed::numeric
END AS launch_speed,
CASE launch_angle
	WHEN 'NaN' THEN NULL
	ELSE launch_angle::numeric
END AS launch_angle,
CASE effective_speed
	WHEN 'NaN' THEN NULL
	ELSE effective_speed::numeric
END AS effective_speed,
CASE estimated_ba_using_speedangle
	WHEN 'NaN' THEN NULL
	ELSE estimated_ba_using_speedangle::numeric
END AS estimated_ba_using_speedangle,
CASE estimated_woba_using_speedangle
	WHEN 'NaN' THEN NULL
	ELSE estimated_woba_using_speedangle::numeric
END AS estimated_woba_using_speedangle,
CASE woba_value
	WHEN 'NaN' THEN NULL
	ELSE woba_value::numeric
END AS woba_value,
CASE woba_denom
	WHEN 'NaN' THEN NULL
	ELSE woba_denom::numeric
END AS woba_denom,
CASE babip_value
	WHEN 'NaN' THEN NULL
	ELSE babip_value::numeric
END AS babip_value,
CASE iso_value
	WHEN 'NaN' THEN NULL
	ELSE iso_value::numeric
END AS iso_value,
CASE launch_speed_angle
	WHEN 'NaN' THEN NULL
	ELSE launch_speed_angle::numeric
END AS launch_speed_angle,
CASE delta_home_win_exp
	WHEN 'NaN' THEN NULL
	ELSE delta_home_win_exp::numeric
END AS delta_home_win_exp,
CASE delta_run_exp
	WHEN 'NaN' THEN NULL
	ELSE delta_run_exp::numeric
END AS delta_run_exp,
post_home_score::numeric,
post_away_score::int
FROM raw_data;