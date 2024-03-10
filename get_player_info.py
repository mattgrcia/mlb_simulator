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


def get_player_info(game_info: dict):

    values = []

    for info in game_info["gameData"]["players"].values():
        player_id = info.get("id")
        player_name = info.get("nameFirstLast")
        player_birthdate = info.get("birthDate")
        player_height = info.get("height")
        player_height = int(player_height.split("'")[0].strip("\\")) * 12 + int(
            player_height.split("'")[1].strip('"').strip()
        )
        player_weight = info.get("weight")
        player_birth_country = info.get("birthCountry")
        player_birth_city = info.get("birthCity")
        player_pos = info.get("primaryPosition")["code"]
        try:
            player_pos = int(player_pos)
        except ValueError:
            player_pos = np.nan

        player_debut = info.get("mlbDebutDate")
        player_last_played = info.get("lastPlayedDate")
        player_active = info.get("active")

        player_bats = info.get("batSide")["code"]
        if player_bats == "R":
            player_bats = 0
        elif player_bats == "L":
            player_bats = 1
        else:
            player_bats = 2

        player_throws = info.get("pitchHand")["description"]
        if player_throws == "Right":
            player_throws = 0
        elif player_throws == "Left":
            player_throws = 1
        else:
            player_throws = 2
        player_sztop = info.get("strikeZoneTop")
        player_szbot = info.get("strikeZoneBottom")

        values.append(
            (
                player_id,
                player_name,
                player_birthdate,
                player_height,
                player_weight,
                player_birth_country,
                player_birth_city,
                player_pos,
                player_debut,
                player_last_played,
                player_active,
                player_bats,
                player_throws,
                player_sztop,
                player_szbot,
            )
        )

    return values


def store_player_info(values: list, connection: PostgresConnector):

    execute_values(
        connection.cur, "INSERT INTO player VALUES %s ON CONFLICT DO NOTHING", values
    )
    connection.conn.commit()

    return None


def main():

    c = PostgresConnector()

    game_ids = get_game_ids(c)

    for game_id in tqdm(game_ids, position=0, leave=True):
        store_player_info(get_player_info(get_game_info(game_id)), c)

    return None


if __name__ == "__main__":
    main()
