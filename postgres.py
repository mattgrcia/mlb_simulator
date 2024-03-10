import os
import psycopg2 as pg


class Connector:

    def __init__(self) -> None:

        self.conn = pg.connect(
            dbname="mlb",
            user="postgres",
            password=os.environ.get("MLB_DB_PW"),
            host="database-1.cqhpcblctccg.us-east-1.rds.amazonaws.com",
        )
        self.cur = self.conn.cursor()

    def reset(self):
        self.__init__()
