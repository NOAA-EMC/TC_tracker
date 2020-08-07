import logging
import pathlib

import numpy as np


def mkparents(output_path):
    if not output_path.parent.exists():
        output_path.parent.mkdir(parents=True, exist_ok=True)


def tracker_output_dir(data_dir, model, basin):
    return pathlib.Path(data_dir, 'tracker', model, basin)


def tracker_output_path(data_dir, model, basin, rundate, storm_id, suffix):
    output_path = pathlib.Path(tracker_output_dir(data_dir, model, basin),
                               '{rundate:%Y%m%d%H}_{model}_{storm_id:02}_{suffix}.txt'.format(
                                    rundate=rundate,
                                    suffix=suffix,
                                    model=model,
                                    storm_id=storm_id,
                               ))
    mkparents(output_path)
    return output_path


def cases_output_path(data_dir, model, basin, rundate, prefix):
    output_path = pathlib.Path(tracker_output_dir(data_dir, model, basin),
                               '{prefix}cases.{rundate:%y%m%d}.{model}{rundate:%H}.txt'.format(
                                   rundate=rundate,
                                   prefix=prefix,
                                   model=model,
                               ))
    mkparents(output_path)
    return output_path


def save_output_text(data            , filepath              , str_fmt=None):
    if isinstance(filepath, pathlib.Path):
        filepath.parent.mkdir(parents=True, exist_ok=True)

    if not isinstance(data, np.ndarray):
        return
    # //TODO: replace this all with a pd dataframe and to_csv output
    # data_pd.to_csv('./df.txt', sep=' ', header=None, index=None, date_format='%Y%m%d')
    logging.info("Saving info to {filepath}".format(filepath=filepath))
    if str_fmt is None:
        str_fmt = '%10.0f%5.0f%12.0f%10.2f%10.2f%10.2f%10.2f%10.2f%10.2f%5.0f%5.0f%5.0f%3.0f'

    if data.ndim == 1:
        data = data[np.newaxis, :]  # make sure it's 2 dimension
    np.savetxt(filepath, data.astype('float'), fmt=str_fmt)
