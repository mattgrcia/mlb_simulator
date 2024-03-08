import os
import pandas as pd

# Specify the path to the folder containing the CSV files
folder_path = "/home/matt/Documents/projects/mlb_simulator/vegas_odds"

# Initialize an empty dataframe
df = pd.DataFrame()

# Iterate over the files in the folder
for file_name in os.listdir(folder_path):
    if file_name.endswith(".csv"):
        file_path = os.path.join(folder_path, file_name)
        # Read the CSV file and append its contents to the dataframe
        df = df.append(pd.read_csv(file_path))

# Now you can use the dataframe 'df' for further processing
# Select the desired columns from the dataframe
df = df[["Home Team Odds", "Away Team Odds", "Total at Close", "Game Date"]]

# Reset the index of the dataframe
df = df.reset_index(drop=True)

# Now you can use the modified dataframe for further processing
