import numpy as np
import psycopg2 as pg
from psycopg2.extras import execute_values
import statsapi
from tqdm import tqdm
from postgres import Connector as PostgresConnector


def nan_to_null(f, _NULL=pg.extensions.AsIs("NULL"), _Float=pg.extensions.Float):
    if not np.isnan(f):
        return _Float(f)
    return _NULL


pg.extensions.register_adapter(float, nan_to_null)


def get_game_ids(connection: PostgresConnector):
    query = "SELECT DISTINCT game_id FROM game;"
    connection.cur.execute(query)
    game_ids = [g[0] for g in connection.cur.fetchall()]

    return game_ids


def get_game_info(game_id: int):

    return statsapi.get("game", params={"gamePk": game_id}, force=False)


def main():

    found_stadiums = {}

    c = PostgresConnector()

    game_ids = get_game_ids(c)

    for game_id in tqdm(game_ids, position=0, leave=True):
        game_info = get_game_info(game_id)

        stadium = game_info["gameData"]["venue"]

        stadium_id = stadium["id"]
        season = stadium["season"]

        if stadium_id not in found_stadiums:
            found_stadiums[stadium_id] = []

            name = stadium["name"]
            address = stadium["location"]["address1"]
            city = stadium["location"]["city"]
            state = stadium["location"]["state"]
            state_abbrev = stadium["location"]["stateAbbrev"]
            postal_code = stadium["location"]["postalCode"]
            country = stadium["location"]["country"]
            latitude = stadium["location"]["defaultCoordinates"]["latitude"]
            longitude = stadium["location"]["defaultCoordinates"]["longitude"]
            try:
                azimuth = stadium["location"]["azimuthAngle"]
            except:
                azimuth = np.nan
            try:
                elevation = stadium["location"]["elevation"]
            except:
                elevation = np.nan
            tz_offset = stadium["timeZone"]["offset"]
            tz = stadium["timeZone"]["tz"]
            active = stadium["active"]

            query = """
                INSERT INTO stadium (
                stadium_id,
                name,
                address,
                city,
                state,
                state_abbrev,
                postal_code,
                country,
                latitude,
                longitude,
                azimuth,
                elevation,
                tz_offset,
                tz,
                active
                )
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                ON CONFLICT (stadium_id) DO NOTHING;
                """
            c.cur.execute(
                query,
                (
                    stadium_id,
                    name,
                    address,
                    city,
                    state,
                    state_abbrev,
                    postal_code,
                    country,
                    latitude,
                    longitude,
                    azimuth,
                    elevation,
                    tz_offset,
                    tz,
                    active,
                ),
            )
            c.conn.commit()

        if season not in found_stadiums[stadium_id]:
            found_stadiums[stadium_id].append(season)

            try:
                capacity = stadium["fieldInfo"]["capacity"]
            except:
                capacity = np.nan
            turf_type = stadium["fieldInfo"]["turfType"]
            roof_type = stadium["fieldInfo"]["roofType"]
            distance_to_left = stadium["fieldInfo"]["leftLine"]
            try:
                distance_to_lc = stadium["fieldInfo"]["leftCenter"]
            except:
                distance_to_lc = stadium["fieldInfo"]["left"]
            distance_to_center = stadium["fieldInfo"]["center"]
            try:
                distance_to_rc = stadium["fieldInfo"]["rightCenter"]
            except:
                distance_to_rc = stadium["fieldInfo"]["right"]
            distance_to_right = stadium["fieldInfo"]["rightLine"]

            query = """
                INSERT INTO stadium_season (
                stadium_id,
                season_year,
                capacity,
                turf_type,
                roof_type,
                dist_to_l,
                dist_to_lc,
                dist_to_c,
                dist_to_rc,
                dist_to_r
                )
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                ON CONFLICT (stadium_id, season_year) DO NOTHING;
                """
            c.cur.execute(
                query,
                (
                    stadium_id,
                    season,
                    capacity,
                    turf_type,
                    roof_type,
                    distance_to_left,
                    distance_to_lc,
                    distance_to_center,
                    distance_to_rc,
                    distance_to_right,
                ),
            )
            c.conn.commit()

    return None


if __name__ == "__main__":
    main()
