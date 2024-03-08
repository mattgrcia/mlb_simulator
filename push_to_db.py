import os
import time
import warnings

warnings.filterwarnings("ignore", category=DeprecationWarning)
import pandas as pd
import psycopg2 as pg
from psycopg2.extras import execute_values


conn = pg.connect(
    dbname="mlb",
    user="postgres",
    password=os.environ.get("MLB_DB_PASSWORD"),
    host="database-1.cqhpcblctccg.us-east-1.rds.amazonaws.com",
)
cur = conn.cursor()

while True:
    if os.listdir("raw_data") == []:
        time.sleep(5)
    for file in os.listdir("raw_data"):
        if file.endswith(".csv"):
            try:
                data = pd.read_csv(f"raw_data/{file}")
            except pd.errors.EmptyDataError:
                os.remove(f"raw_data/{file}")
                continue
            values = [tuple(x) for x in data.to_numpy()]
            execute_values(cur, "INSERT INTO raw_data VALUES %s", values)
            conn.commit()
            os.remove(f"raw_data/{file}")
