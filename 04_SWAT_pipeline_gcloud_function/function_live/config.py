import numpy as np

target_files = ['rsv', 'rch', 'sed', 'vel', 'hru', 'sub', 'pst']

unique_locations = {'rsv' : 4,
                    'rch' : 332,
                    'sed' : 332,
                    'vel' : 1,
                    'hru' : 2169,
                    'sub' : 332}


file_skips = {'rsv' : 9,
                'rch' : 9,
                'sed' : 1,
                'vel' : 2,
                'hru' : 9,
                'sub' : 9,
		'pst' : 11}


n_fixed_cols = {'rsv' : 3,
                'rch' : 6,
                'sed' : 4,
                'vel' : 2,
                'hru' : 7,
                'sub' : 5}

fixed_col_widths = {'rsv' : [11, 3, 5],
                    'rch' : [7, 3, 9, 6, 12],
                    'sed' : [7, 3, 9, 6],
                    'vel' : [5, 5],
                    'hru' : [4, 5, 10, 5, 5, 5, 10],
                    'sub' : [7, 3, 9, 5, 10],
		    'pst' : [10, 5, 4, 17, 17]}

fixed_col_dtypes = {'rsv' : ['str', np.int32, np.int32],
                    'rch' : ['str', np.int32, 'str', np.int32, np.float64],
                    'sed' : ['str', np.int32, 'str', np.int32],
                    'vel' : [np.int32, np.int32],
                    'hru' : ['string', np.int16, 'string', np.int16, np.int8, np.int16, np.float32],
                    'sub' : ['str', np.int16, 'str', np.int16, np.float32]}

var_col_width = {'rsv' : 12,
                'rch' : 12,
                'sed' : 12,
                'vel' : 12,
                'hru' : 10,
                'sub' : 10}


file_cut = ['rsv', 'rch', 'sed', 'sub']