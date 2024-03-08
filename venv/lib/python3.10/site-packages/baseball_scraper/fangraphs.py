import shutil
import pandas as pd
import importlib.resources as pkg_resources
from selenium.webdriver.common.by import By
from baseball_scraper import selenium_helper
from enum import Enum, auto


class ScrapeType(Enum):
    HITTER = auto()
    PITCHER = auto()


class Scraper:
    instance_map = {"Steamer (RoS)": "steamerr",
                    "Steamer (Update)": "steameru",
                    "ZiPS (Update)": "uzips",
                    "Steamer600 (Update)": "steamer600u",
                    "Depth Charts (RoS)": "rfangraphsdc",
                    "THE BAT (RoS)": "rthebat"}

    """Pulls baseball stats from fangraphs.com

    :param instance: What data source we are going to pull from.  See
    instances() for a list of available names.
    :type instance: str
    """
    def __init__(self, instance):
        instance_uri = self._get_instance_uri(instance)
        self.hitting_scraper = ScraperGeneral(self._uri(instance_uri, "bat"))
        self.pitching_scraper = ScraperGeneral(self._uri(instance_uri, "pit"))

    def scrape(self, id, id_name="playerid", scrape_as=ScrapeType.HITTER):
        """Generate a DataFrame of the stats that we pull from fangraphs.com

        :param ids: The lookup value(s).  If id_name is 'player_id' this would
        be the FanGraphs ID of the player you want to scrape.  You can pass in
        a single ID or a list of IDs.
        :type player_id: str or list(str)
        :param id_name: Name of the ID to lookup.  Set this to 'player_id' if
        your id is the FanGraphs ID.  Other options include: Name, Team.
        :type name: str
        :param scrape_as: Identity what to scrape a hitter or pitcher
        :type scrape_as: ScrapeType
        :return: panda DataFrame of stat categories for the players.  Returns
          an empty DataFrame if nothing was found
        :rtype: DataFrame
        """
        if scrape_as == ScrapeType.HITTER:
            return self.hitting_scraper.scrape(id, id_name)
        elif scrape_as == ScrapeType.PITCHER:
            return self.pitching_scraper.scrape(id, id_name)
        else:
            raise RuntimeError("Unknown scrape type: {}".format(scrape_as))

    @classmethod
    def instances(cls):
        """Return a list of available data instances for the player

        A data instance can be historical data of a particular year/team or it
        can be from a prediction system.

        :return: Names of the available sources
        :rtype: list(str)
        """
        return cls.instance_map.keys()

    def load_fake_cache(self):
        self.hitting_scraper.load_fake_cache(
            'sample.fangraphs.hitter_leaderboard.csv')
        self.pitching_scraper.load_fake_cache(
            'sample.fangraphs.pitcher_leaderboard.csv')

    def _get_instance_uri(self, instance):
        if instance not in self.instance_map:
            raise RuntimeError("The instance given is not a valid one.  Use " +
                               "instances() to see available ones.")
        return self.instance_map[instance]

    def _uri(self, instance_uri, stat_type):
        return "https://www.fangraphs.com/projections.aspx?" + \
            "pos=all&stats={}&type={}".format(stat_type, instance_uri)


class ScraperGeneral:
    download_file = "FanGraphs Leaderboard.csv"

    """Pulls baseball stats for a single player from fangraphs.com

    :param uri: The URI to download the stats from
    :type uri: str
    """
    def __init__(self, uri):
        self.uri = uri
        self.df_source = None  # File name to read the csv data from
        self.df = None
        self.dlr = selenium_helper.Downloader(self.uri, self.download_file)

    def __getstate__(self):
        return (self.uri, self.df)

    def __setstate__(self, state):
        (self.uri, self.df) = state
        self.df_source = None
        self.dlr = selenium_helper.Downloader(self.uri, self.download_file)

    def scrape(self, ids, id_name):
        """Generate a DataFrame of the stats that we pulled from fangraphs.com

        :param ids: The lookup value(s).  If id_name is 'player_id' this would
        be the FanGraphs ID of the player you want to scrape.  You can pass in
        a single ID or a list of IDs.
        :type player_id: str or list(str)
        :param id_name: Name of the ID to lookup.  Set this to 'player_id' if
        your id is the FanGraphs ID.  Other options include: name, team.
        :type name: str
        :return: panda DataFrame of stat categories for the lookup values.
        Returns an empty DataFrame if lookup did not find anything.
        :rtype: DataFrame
        """
        self._cache_source()
        if isinstance(ids, list):
            return self.df[self.df[id_name].isin(ids)].reset_index()
        else:
            if str(self.df[id_name].dtype) == "int64":
                return self.df[self.df[id_name] == int(ids)].reset_index()
            else:
                return self.df[self.df[id_name] == str(ids)].reset_index()

    def set_source(self, s):
        self.df_source = s

    def save_source(self, f):
        shutil.copy(self.dlr.downloaded_file(), f)

    def load_fake_cache(self, sample_file):
        with pkg_resources.open_binary('baseball_scraper', sample_file) as fo:
            self.df = None
            self.df_source = fo
            self._cache_source()

    def _cache_source(self):
        if self.df is None:
            if self.df_source is None:
                self._download()
                self.df_source = self.dlr.downloaded_file()
            self.df = pd.read_csv(self.df_source)

    def _download(self):
        self.dlr.download_by_clicking(By.LINK_TEXT, 'Export Data')
