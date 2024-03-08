import numpy as np
import pandas as pd
import requests
from bs4 import BeautifulSoup
import datetime as dt


class TeamScraper:
    """Pulls team results for a particular date range"""
    def __init__(self):
        self.team = None
        self.start_date = None
        self.end_date = None
        self.season_raw_cache = {}
        self.season_cache = {}

    def __getstate__(self):
        return (self.team, self.start_date, self.end_date, self.season_cache)

    def __setstate__(self, state):
        (self.team, self.start_date, self.end_date, self.season_cache) = state
        self.season_raw_cache = {}

    def set_season(self, season):
        """Set the season to scrape

        Convenience function to start the start/stop for a given season.

        :param season: Season year to scrape
        :type season: int
        """
        self.set_date_range(dt.date(season, 1, 1),
                            dt.date(season, 12, 31))

    def set_date_range(self, start_date, end_date):
        """Set the date range to scrape

        :param start_date: Starting date (inclusive)
        :type start_date: datetime.date
        :param end_date: Ending date (inclusive)
        :type end_date: datetime.date
        """
        self._validate_date_range(start_date, end_date)
        self.start_date = pd.Timestamp(start_date)
        self.end_date = pd.Timestamp(end_date)

    def scrape(self, team):
        """Scrape the results for a team given a date range

        :param team: The abbreviation of the team to scrape
        :type team: str
        :return: Rows of games for the given date over the date range
        :rtype: pandas.DataFrame
        """
        self.team = team.upper()
        self._validate_date_range(self.start_date, self.end_date)
        self._validate_team()
        self._cache_source()
        df = self.season_cache[self.team][self.start_date.year]
        return self._apply_filters(df)

    def set_source(self, team, s):
        self._validate_date_range(self.start_date, self.end_date)
        if team not in self.season_raw_cache:
            self.season_raw_cache[team] = {}
        self.season_raw_cache[team][self.start_date.year] = s

    def save_source(self, team, f):
        assert(team in self.season_raw_cache)
        assert(self.start_date.year in self.season_raw_cache[team])
        with open(f, "w") as fo:
            fo.write(str(self.season_raw_cache[team][self.start_date.year]))

    def _validate_date_range(self, st, ed):
        if st is None:
            raise RuntimeError("Must specify start date")
        if ed is None:
            raise RuntimeError("Must specify end date")
        if st.year != ed.year:
            raise RuntimeError("Start/end date must be from the same season")
        if st > ed:
            raise RuntimeError("Start date must be before end date")
        if ed.year > dt.datetime.now().year:
            raise RuntimeError("Season cannot be past the current year")

    def _validate_team(self):
        if self.team is None:
            raise RuntimeError("Must specify a team")

    def _url(self):
        return "http://www.baseball-reference.com/" + \
            "teams/{}/{}-schedule-scores.shtml".format(self.team,
                                                       self.start_date.year)

    def _cache_source(self):
        yr = self.start_date.year
        if self.team not in self.season_cache or \
                yr not in self.season_cache[self.team]:
            if self.team not in self.season_raw_cache or \
                    yr not in self.season_raw_cache[self.team]:
                self._soup()
            soup = self.season_raw_cache[self.team][yr]
            if self.team not in self.season_cache:
                self.season_cache[self.team] = {}
            self.season_cache[self.team][yr] = self._parse_raw(soup)

    def _soup(self):
        s = requests.get(self._url()).content
        if self.team not in self.season_raw_cache:
            self.season_raw_cache[self.team] = {}
        self.season_raw_cache[self.team][self.start_date.year] = \
            BeautifulSoup(s, "lxml")

    def _parse_raw(self, soup):
        table = self._get_table(soup)
        data = []
        headings = [th.get_text() for th in table.find("tr").find_all("th")]
        headings = headings[1:]  # the gm# heading doesn't have a <td> element
        headings[3] = "Home_Away"
        data.append(headings)
        table_body = table.find('tbody')
        rows = table_body.find_all('tr')
        # Iterate up to but not including last row.  The last row is a
        # description of column meanings.
        for row_index in range(len(rows)-1):
            row = rows[row_index]
            cols = self._parse_row(row)
            if len(cols) > 0:
                data.append([ele for ele in cols if ele])

        # Convert to pandas dataframe. make first row the table's column names
        # and reindex.
        data = pd.DataFrame(data)
        data = data.rename(columns=data.iloc[0])
        data = data.reindex(data.index.drop(0))
        data = data.drop('', 1)  # not a useful column
        data = self._process_win_streak(data)
        data = self._make_numeric(data)
        data = self._process_date(data)
        return data

    def _get_table(self, soup):
        try:
            return soup.find_all('table')[0]
        except IndexError:
            raise ValueError("Data cannot be retrieved for this team/year " +
                             "combo. Please verify that your team " +
                             "abbreviation is accurate and that the team " +
                             "existed during the season you are searching " +
                             "for. Team={}; Year={}".
                             format(self.team, self.start_date.year))

    def _parse_row(self, row):
        """Parse a row and split it up into columns.

        The result is a list of column values that are suitable for inclusion
        into a DataFrame.

        :param row: Row from the table as extracted by BeautifulSoup
        :type row: BeautifulSoup table row
        :return: Column values
        :rtype: List
        """
        cols = None
        try:
            cols = row.find_all('td')
            cols = self._reformat_col_value(cols)
            cols = [ele.text.strip() for ele in cols]
        except IndexError:
            # Two cases will break the above: games that haven't happened yet,
            # and BR's redundant mid-table headers if future games, grab the
            # scheduling info. Otherwise do nothing.
            if len(cols) > 1:
                cols = [ele.text.strip() for ele in cols][0:5]
        return cols

    def _reformat_col_value(self, cols):
        if cols[1].text == "":
            # some of the older season don't seem to have team abbreviation
            # on their tables
            cols[1].string = self.team
        if cols[3].text == "":
            # This element only has an entry if it's an away game
            cols[3].string = 'Home'
        if cols[12].text == "":
            # tie games won't have a pitcher win or loss
            cols[12].string = "None"
        if cols[13].text == "":
            cols[13].string = "None"
        if cols[14].text == "":
            # games w/o saves have blank td entry
            cols[14].string = "None"
        if cols[8].text == "":
            # entry is blank if no extra innings
            cols[8].string = "9"
        if cols[16].text == "":
            cols[16].string = "Unknown"
        if cols[15].text == "":
            cols[15].string = "Unknown"
        if cols[17].text == "":
            cols[17].string = "Unknown"
        return cols

    def _process_win_streak(self, data):
        """Convert the win streak column to integers

        The win streak column has values like "+++"/"---".  This converts them
        into a +/- integer column.

        :param data: Current team data
        :type data: DataFrame
        :return: Modified team data
        :rtype: DataFrame
        """
        # only do this if there are non-NANs in the column
        if data['Streak'].count() > 0:
            data['Streak2'] = data['Streak'].str.len()
            data.loc[data['Streak'].str[0] == '-', 'Streak2'] = \
                -data['Streak2']
            data['Streak'] = data['Streak2']
            data = data.drop('Streak2', 1)
        return data

    def _make_numeric(self, data):
        """Ensure some columns in DataFrame are true numeric types

        :param data: Current team data
        :type data: DataFrame
        :return: Modified team data
        :rtype: DataFrame
        """
        # First remove commas from attendance values.  Skip if column is all NA
        #  -- not sure if everyone kept records in the early days.
        if data['Attendance'].count() > 0:
            data['Attendance'] = data['Attendance'].str.replace(',', '')
        else:
            data['Attendance'] = np.nan

        # Replace unknown with NaN so that column can be numeric
        data['Attendance'].replace(r'^Unknown$', np.nan, regex=True,
                                   inplace=True)

        # now make everything numeric
        num_cols = ["R", "RA", "Inn", "Rank", "Attendance"]
        data[num_cols] = data[num_cols].astype(float)  # not int b/c of NaNs
        return data

    def _process_date(self, data):
        """Ensure date column is a true datetime python object

        :param data: Current team data
        :type data: DataFrame
        :return: Modified team data
        :rtype: DataFrame
        """
        def helper(val):
            # Sometime the date has a (1) or (2) following it.  Strip that off
            # so that we can successful convert to date.
            s = val.find(" (")
            if s >= 0:
                val = val[0:s]
            dv = dt.datetime.strptime(val, '%A, %b %d')
            dv = dv.replace(year=self.start_date.year)
            return dv
        data['Date'] = data['Date'].apply(helper)
        return data

    def _apply_filters(self, df):
        """Apply filters to the DataFrame to limit the number of rows in it.

        :param df: The full data frame extracted from the website
        :type df: DataFrame
        :return: Filtered DataFrame
        :rtype: DataFrame
        """
        df = df[(df['Date'] >= self.start_date) &
                (df['Date'] <= self.end_date)]
        return df


class TeamSummaryScraper:
    """A scraper that retrieves a summary of all of the baseball teams

    >>> from baseball_scraper import baseball_reference
    >>> tss = baseball_reference.TeamSummaryScraper()
    >>> df = tss.scrape(2019)
    >>> df.columns
    Index([u'Franchise',        u'Tm',      u'#Bat',    u'BatAge',       u'R/G',
                   u'G',        u'PA',        u'AB',         u'R',         u'H',
                  u'2B',        u'3B',        u'HR',       u'RBI',        u'SB',
                  u'CS',        u'BB',        u'SO',        u'BA',       u'OBP',
                 u'SLG',       u'OPS',      u'OPS+',        u'TB',       u'GDP',
                 u'HBP',        u'SH',        u'SF',       u'IBB',       u'LOB'],
         dtype='object')
    """ # noqa
    def __init__(self):
        self.year = None
        self.cache = {}
        self.raw_cache = {}

    def __getstate__(self):
        return (self.cache)

    def __setstate__(self, state):
        (self.cache) = state
        self.raw_cache = {}

    def scrape(self, year):
        """Scrape baseball-reference.com to get a list of all teams

        This only returns the active teams.

        :param year: The year to get the abbreviations for
        :type year: int
        :return: Teams and their abbreviations
        :rtype: pandas.DataFrame
        """
        self._cache_source(year)
        return self.cache[year]

    def set_source(self, s, year):
        self.raw_cache[year] = s

    def save_source(self, f, year):
        assert(year in self.raw_cache)
        with open(f, "w") as fo:
            fo.write(str(self.raw_cache[year]))

    def _cache_source(self, year):
        if year not in self.cache:
            if year not in self.raw_cache:
                self._soup(year)
            self._parse_raw(year)

    def _soup(self, year):
        s = requests.get(self._url(year)).content
        self.raw_cache[year] = BeautifulSoup(s, "lxml")

    def _url(self, year):
        return "https://www.baseball-reference.com/leagues/MLB/{}.shtml" \
            .format(year)

    def _parse_raw(self, year):
        table = self.raw_cache[year].find_all('table')[0]
        headings = ["Franchise"] + \
            [th.get_text() for th in table.find("tr").find_all("th")]
        assert(headings[1] == "Tm")
        headings[1] = "abbrev"
        df = pd.DataFrame(data=[], columns=headings)
        table_body = table.find('tbody')
        rows = table_body.find_all('tr')
        for row in rows:
            cols = self._parse_team(row)
            if cols is not None:
                df = df.append(pd.DataFrame(data=[cols], columns=headings),
                               ignore_index=True)
        self.cache[year] = df

    def _parse_team(self, row):
        th = row.find_all("th")
        assert(len(th) == 1)
        tm_anchor = th[0].find_all('a')
        if len(tm_anchor) == 1:
            cols = []
            assert("title" in tm_anchor[0].attrs)
            cols.append(tm_anchor[0].attrs["title"])
            cols.append(th[0].text)
            for col in row.find_all("td"):
                cols.append(col.text)
            return cols
        else:
            return None
