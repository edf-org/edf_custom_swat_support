
import config as cfg
import pandas as pd

def format_rsv(df, model_period, cio_dict):

    if model_period == 'monthly':
            
        try:
            # pull min and max year values from MON field (which contains days, months & years)
            year_start = int(min(df[df['MON'] > 100].MON))
            year_end = int(max(df[df['MON'] > 100].MON))
        
        except:
            print("Expecting annual averages in monthly file but none found. Is model time interval defined correctly?")
            raise
                
        # remove annual summaries throughout file, i.e. where MON is not a month or day value
        df = df[df['MON'] < 1000]
    
        # create array of year values to match date sequence in monthly file
        df['year'] = [i for i in range(year_start, year_end + 1) for k in range(0, (cfg.unique_locations['rsv'] * 12))]

    if model_period == 'daily': 
        
        # year column already exists, no need to add in
        df = df

    return df


def format_rch(df, model_period, cio_dict):

    if model_period == 'monthly':
            
        try:
            # pull min and max year values from MON field (which contains days, months & years)
            year_start = int(min(df[df['MON'] > 100].MON))
            year_end = int(max(df[df['MON'] > 100].MON))
        
        except:
            print("Expecting annual averages in monthly file but none found. Is model time interval defined correctly?")
            raise
                
        # remove annual summaries throughout file, i.e. where MON is not a month or day value
        df = df[df['MON'] < 1000]

        # cut off total average summary from bottom of file
        df = df.iloc[0:len(df)-332, :]
    
        # create array of year values to match date sequence in monthly file
        df['year'] = [i for i in range(year_start, year_end + 1) for k in range(0, (cfg.unique_locations['rch'] * 12))]
        # set empty value for day, which doesn't exist in monthly output, but does in daily
        df['day'] = 0

    if model_period == 'daily': 
        
        try:
            start = '01/01/' + str(cio_dict['year_start'])
            end = '31/12/' + str(cio_dict['year_start'] + cio_dict['n_years'] - 1)
            
            # create array of year values to match date sequence in daily file
            df['year'] = [i for i in pd.date_range(start = start, end = end, freq = 'D').year for k in range(0, (cfg.unique_locations['rch']))]
    
        except:
            print("Length of daily output file is not as expected from the file.cio, please check they're from the same model run")
            raise

    return df


def format_sed(df, model_period, cio_dict):

    if model_period == 'monthly':
            
        try:
            # pull min and max year values from MON field (which contains days, months & years)
            year_start = int(min(df[df['MON'] > 100].MON))
            year_end = int(max(df[df['MON'] > 100].MON))
        
        except:
            print("Expecting annual averages in monthly file but none found. Is model time interval defined correctly?")
            raise
                
        # remove annual summaries throughout file, i.e. where MON is not a month or day value
        df = df[df['MON'] < 1000]

        # cut off total average summary from bottom of file
        df = df.iloc[0:len(df)-332, :]
    
        # create array of year values to match date sequence in monthly file
        df['year'] = [i for i in range(year_start, year_end + 1) for k in range(0, (cfg.unique_locations['sed'] * 12))]

    if model_period == 'daily': 
        
        try:
            start = '01/01/' + str(cio_dict['year_start'])
            end = '31/12/' + str(cio_dict['year_start'] + cio_dict['n_years'] - 1)
            
            # create array of year values to match date sequence in daily file
            df['year'] = [i for i in pd.date_range(start = start, end = end, freq = 'D').year for k in range(0, (cfg.unique_locations['sed']))]
    
        except:
            print("Length of daily output file is not as expected from the file.cio, please check they're from the same model run")
            raise

    return df


def format_vel(df, model_period, cio_dict):

    df = df.melt(id_vars = ['Day', 'Year'], var_name = "sub", value_name = "velocity")

    return df


def format_hru(df, model_period, cio_dict):

    if model_period == 'monthly':
            
        try:
            # pull min and max year values from MON field (which contains days, months & years)
            year_start = int(min(df[df['MON'] > 100].MON))
            year_end = int(max(df[df['MON'] > 100].MON))
        
        except:
            print("Expecting annual averages in monthly file but none found. Is model time interval defined correctly?")
            raise
                
        # remove annual summaries throughout file, i.e. where MON is not a month or day value
        df = df[df['MON'] < 1000]

        # cut off total average summary from bottom of file
        df = df.iloc[0:len(df)-332, :]
    
        # create array of year values to match date sequence in monthly file
        df['year'] = [i for i in range(year_start, year_end + 1) for k in range(0, (cfg.unique_locations['hru'] * 12))]

    if model_period == 'daily': 
        
        try:
            start = '01/01/' + str(cio_dict['year_start'])
            end = '31/12/' + str(cio_dict['year_start'] + cio_dict['n_years'] - 1)
            
            # create array of year values to match date sequence in daily file
            df['year'] = [i for i in pd.date_range(start = start, end = end, freq = 'D').year for k in range(0, (cfg.unique_locations['hru']))]
    
        except:
            print("Length of daily output file is not as expected from the file.cio, please check they're from the same model run")
            raise
    return df
