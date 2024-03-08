import datetime
from baseball_scraper import statcast

date = datetime.datetime.strptime("2008-03-24", "%Y-%m-%d").date()
end_date = datetime.datetime.strptime("2023-11-25", "%Y-%m-%d").date()

while date < end_date:
    date += datetime.timedelta(days=1)
    formatted_date = date.strftime("%Y-%m-%d")
    data = statcast(start_dt=formatted_date, end_dt=formatted_date)

    if len(data) == 0:
        continue

    data.to_csv(f"raw_data/{date}.csv", index=False)
