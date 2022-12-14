
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

        # create empty conc field for previous table format
        df['SEDCONC'] = 0


    if model_period == 'daily': 
        
        try:
            # create array of year values to match date sequence in daily file
            y_arr = [i for i in pd.date_range(start = cio_dict['start'], end = cio_dict['end'], freq = 'D').year for k in range(0, (cfg.unique_locations['rch']))]
            df['year'] = y_arr
    
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
            # create array of year values to match date sequence in daily file
            df['year'] = [i for i in pd.date_range(start = cio_dict['start'], end = cio_dict['end'], freq = 'D').year for k in range(0, (cfg.unique_locations['sed']))]
    
        except:
            print("Length of daily output file is not as expected from the file.cio, please check they're from the same model run")
            raise

    return df


def format_vel(df, model_period, cio_dict):

    df = df.melt(id_vars = ['Day', 'Year'], var_name = "sub", value_name = "velocity")

    return df



def format_hru(df, model_period, cio_dict, chunk_s, chunk_n, chunk_l):

    if model_period == 'monthly':
            
        raise ValueError("Unable to process hru files in monthly format, please try daily.")

    if model_period == 'daily': 
        
        try:
            year_rng = pd.date_range(start = cio_dict['start'], 
                                     end = cio_dict['end'], 
                                     freq = 'D').year
            
            # create array of year values to match date sequence in daily file
            year_arr = [i for i in year_rng for k in range(0, (cfg.unique_locations['hru']))]
            
            # take just year values for current chunk and add to df
            targ = year_arr[chunk_n * chunk_s : (chunk_n * chunk_s) + chunk_l]
            df['year'] = targ
    
        except:
            print("Length of daily output file is not as expected from the file.cio, please check they're from the same model run")
            raise
            
    return df


def format_sub(df, model_period, cio_dict, chunk_s, chunk_n, chunk_l):

    if model_period == 'monthly':
            
        raise ValueError("Unable to process sub files in monthly format, please try daily.")

    if model_period == 'daily': 
        
        try:
            year_rng = pd.date_range(start = cio_dict['start'], 
                                     end = cio_dict['end'], 
                                     freq = 'D').year
            
            # create array of year values to match date sequence in daily file
            year_arr = [i for i in year_rng for k in range(0, (cfg.unique_locations['sub']))]
            
            # take just year values for current chunk and add to df
            targ = year_arr[chunk_n * chunk_s : (chunk_n * chunk_s) + chunk_l]
            df['year'] = targ
    
        except:
            print("Length of daily output file is not as expected from the file.cio, please check they're from the same model run")
            raise

    return df


def format_pst(df, model_period, cio_dict):

    # formatting here is very simple
    # the file contains YEAR so no need to do fiddly date inference from cio file.
    # And both monthly and daily formats have annual summary of same type at the bottom
    # so can be treated the same.
    # Simply dropping NAs removes the annual summary from the bottom for 
    # both daily and monthly files, as well as the NAs throughout for monthly
    
    # remove NAs
    df = df.dropna(axis=0)
    
    # update column dtypes
    col_dtypes = {'GIS' : str, 
              'YEAR' : int, 
              'MON' : int, 
              'SOLUBLE' : float, 
              'SORBED' : float, 
              'chem_value' : int}

    try:
        df = df.astype(col_dtypes)
    
    except:
        print("Field is of the wrong data type, check format is as expected and NAs are being removed by format_pst.")
        raise
    
    return df