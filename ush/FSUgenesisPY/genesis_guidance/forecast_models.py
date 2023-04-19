import logging
import pathlib
from datetime import timedelta
from enum import Enum
import os
import sys

import numpy as np
import vorpy.calc as mpcalc
import grib2py

if sys.version_info[0] == 2:
    from ConfigParser import RawConfigParser
    FileNotFoundError = RuntimeError
else:
    from configparser import RawConfigParser


def subset_grid(data_grid            , y     , x     , extent      )              :
    ymin = y - extent['ym']
    ymax = y + extent['yp']
    xmin = x - extent['xm']
    xmax = x + extent['xp']
    return data_grid[ymin:ymax, xmin:xmax]


class Models(Enum):
    gfs = 1
    cmc = 2
    ukm = 3
    ecm = 4
    nav = 5


class ModelDefinition:
    def __init__(
            self,
            model_name,
            basin,
            rundate=None,
            fname_template=None
    ):
        self.model_name = model_name
        self.basin = basin
        self.rundate = rundate
#        self.fname_template = None
        self.fname_template = fname_template
        self.model_num = Models[model_name].value
        self._data = {}
        self._data_fhr = None
        self._latdiff = None
        self._londiff = None
        self.load_coefficients()
        self.load_config()

    def load_config(self):
        config = RawConfigParser({'min_fhr': 0, 'max_fhr': 180, 'delta_fhr': 6})
        config.read(
            os.path.join(os.path.abspath(os.path.dirname(__file__)), 'model_config.cfg'))
#        self.fname_template = config.get(self.model_name, 'fname_template')
        self.min_fhr = config.getint(self.model_name, 'min_fhr')
        self.max_fhr = config.getint(self.model_name, 'max_fhr') + 1
        self.delta_fhr = config.getint(self.model_name, 'delta_fhr')

    @property
    def deg2box(self):
        return {
            'ym': int(round(2 / self._latdiff, 0)),
            'yp': int(round(2 / self._latdiff, 0)) + 1,
            'xm': int(round(2 / self._londiff, 0)),
            'xp': int(round(2 / self._londiff, 0)) + 1,
        }

    @property
    def deg5box(self):
        return {
            'ym': int(round(5 / self._latdiff, 0)),
            'yp': int(round(5 / self._latdiff, 0)) + 1,
            'xm': int(round(5 / self._londiff, 0)),
            'xp': int(round(5 / self._londiff, 0)) + 1,
        }

    def load_coefficients(self, ):
        config = RawConfigParser()
        config.read(
            os.path.join(os.path.abspath(os.path.dirname(__file__)), 'coefficients.cfg'))
        self.coefficients = config

    @property
    def vthresh(self)         :
        return self.coefficients.getfloat('vthresh.{}'.format(self.basin), self.model_name)

    @property
    def ththresh(self)         :
        return self.coefficients.getfloat('ththresh.{}'.format(self.basin), self.model_name)

    @property
    def wsthresh(self)         :
        return self.coefficients.getfloat('wsthresh.{}'.format(self.basin), self.model_name)

    @property
    def f_hours(self, ):
        return range(self.min_fhr, self.max_fhr, self.delta_fhr)

    def filename(self, fhr     )       :
        return self.fname_template.format(date=self.rundate, fhr=fhr)

    def filepath(self, fhr     )       :
        return pathlib.Path(self.filename(fhr=fhr))

    def read_grib(self, fhour, varname, grib_kwargs, flip_lat=False, scale=None):
        with grib2py.open(str(self.filepath(fhr=fhour))) as gbfile:
            try:
                tmpdata = gbfile.select(**grib_kwargs)[0]
            except ValueError as exc:
                logging.error("{grib_kwargs} not found in"
                              "{filepath}".format(
                                  grib_kwargs=grib_kwargs,
                                  filepath=self.filepath(fhour),
                              ))
                raise exc

            if scale is not None:
                tmpdata.values *= scale
            logging.debug('{fhr:03} - {varname} : max:{max}, min:{min}'.format(
                fhr=fhour,
                varname=varname,
                max=np.max(tmpdata.values),
                min=np.min(tmpdata.values)))
            if flip_lat:
                tmpvalues = np.flipud(tmpdata.values)
                self._data[varname] = tmpvalues.copy()
            else:
                tmpvalues = tmpdata.values
                self._data[varname] = tmpvalues.copy()

            if 'lat1d' not in self._data:
                lats, lons = tmpdata.latlons()
                if flip_lat:
                    self._data['lat1d'] = lats[::-1, 0]
                else:
                    self._data['lat1d'] = lats[:, 0]
                self._data['lon1d'] = lons[0, :]
                self._latdiff = self._data['lat1d'][1] - self._data['lat1d'][0]
                self._londiff = self._data['lon1d'][1] - self._data['lon1d'][0]
                logging.debug('Lat Extent: {latmin}:{latmax}:{latdiff}'.format(
                    latmin=self._data['lat1d'][0],
                    latmax=self._data['lat1d'][-1],
                    latdiff=self._latdiff))
                logging.debug('Lon Extent: {lonmin}:{lonmax}:{londiff}'.format(
                    lonmin=self._data['lon1d'][0],
                    lonmax=self._data['lon1d'][-1],
                    londiff=self._londiff))

        return self._data[varname]

    def check_for_input_files(self):
        for fh in self.f_hours:
            filepath = self.filepath(fhr=fh)
            if not filepath.is_file():
                logging.warning("File Not Found: {filepath}".format(filepath=filepath))
                raise FileNotFoundError('All files are not ready yet')
        logging.info('All files are available')

    def get_mslp_min(self, mslp_grid, y, x):
        ''' Check local min (probably not needed anymore)
            Check if local min has "closed" contours at 5 degrees
        '''
        sarea = mslp_grid[y - 1:y + 2, x - 1:x + 2]
        pmin = np.min(sarea)
        pminx = np.where(sarea == np.min(sarea))[1][0]
        pminy = np.where(sarea == np.min(sarea))[0][0]
        if pminx == 1 and pminy == 1:
            sarea = subset_grid(mslp_grid, y, x, self.deg5box)
            pmint = np.min(sarea[0, :])
            pminb = np.min(sarea[-1, :])
            pminl = np.min(sarea[:, 0])
            pminr = np.min(sarea[:, -1])
            if (pmin + 200) <= np.min([pmint, pminb, pminl, pminr]):
                return pmin
        return None

    def get_interior_max(self, data_grid, y, x):
        '''Checks for maximum not on boundary of grid '''
        sub_area = subset_grid(data_grid, y, x, self.deg2box)
        local_max = np.max(sub_area)
        interior_max = np.max(sub_area[1:-1, 1:-1])
        if local_max == interior_max:
            return local_max
        else:
            return None

    def get_wspd_max(self, data_grid, y, x):
        wsarea = subset_grid(data_grid, y, x, self.deg5box)
        wsmax = np.max(wsarea)
        return wsmax

    def check_minmax_criteria(self, fhour     , y, x):
        pmin = self.get_mslp_min(self.data(fhour, 'mslp'), y, x)
        if pmin is None:
            return False, None
        vmax = self.get_interior_max(self.data(fhour, 'vor'), y, x)
        if vmax is None:
            return False, None
        thmax = self.get_interior_max(self.data(fhour, 'thck'), y, x)
        if thmax is None:
            return False, None
        wsmax = self.get_wspd_max(self.data(fhour, 'ws925'), y, x)
        if wsmax < 10:
            logging.debug("Fail on wspd: ({pmin}, {vmax}, {thmax}, {wsmax})".format(
                pmin=pmin,
                vmax=vmax,
                thmax=thmax,
                wsmax=wsmax,
            ))
            return False, None
        return True, (pmin, vmax, thmax, wsmax)

    def calc_B_parameters(self, fh     , y     , x     ):
        if self.basin == 'epac':
            return self.calc_epac_B_parameters(fh, y, x)
        elif self.basin == 'natl':
            return self.calc_natl_B_parameters(fh, y, x)

    def calc_natl_B_parameters(self, fh     , y     , x     )                  :
        raise NotImplementedError

    def calc_epac_B_parameters(self, fh     , y     , x     )                  :
        raise NotImplementedError

    def basin_bbox(self):
        if self.basin == 'natl':
            return {
                'latmin': 5.,
                "lonmin": 260.,
                "lonmax": 340.,
                "latmax": 45.,
            }
        elif self.basin == 'epac':
            return {
                'latmin': 5.,
                "lonmin": 180.,
                "lonmax": 275.,
                "latmax": 33.,
            }

    def data(self, fhour     , varname     )        :
        raise NotImplementedError('Instantiate a specific ModelDefinition')


class GFSDefinition(ModelDefinition):
    def data(self, fhour     , varname     )        :
        if (varname in self._data) and (fhour == self._data_fhr):
            return self._data[varname]

        if self._data_fhr is None:
            self._data_fhr = fhour

        if fhour != self._data_fhr:
            self._data = {}
            self._data_fhr = fhour

        short_name_to_gribkwargs = {
            'mslp': {
                'shortName': 'mslet',
            },
            'u925': {
                'shortName': 'u',
                'level': 925
            },
            'u800': {
                'shortName': 'u',
                'level': 800
            },
            'u850': {
                'shortName': 'u',
                'level': 850
            },
            'v850': {
                'shortName': 'v',
                'level': 850
            },
            'u200': {
                'shortName': 'u',
                'level': 200
            },
            'v925': {
                'shortName': 'v',
                'level': 925
            },
            'v800': {
                'shortName': 'v',
                'level': 800
            },
            'v200': {
                'shortName': 'v',
                'level': 200
            },
            'gh850': {
                'shortName': 'gh',
                'level': 850
            },
            'rh600': {
                'shortName': 'r',
                'level': 600
            },
            'gh250': {
                'shortName': 'gh',
                'level': 250
            },
            'lh': {
                'shortName': 'lhtfl'
            },
            'cape': {
                'shortName': 'cape'
            }
        }

        if varname == 'lh' and fhour == 0:
            return None

        grib_kwargs = short_name_to_gribkwargs.get(varname, None)
        if grib_kwargs is not None:
            return self.read_grib(fhour, varname, grib_kwargs, flip_lat=True)

        if (varname == 'lon1d') or (varname == 'lat1d'):
            if varname not in self._data:
                _ = self.data(fhour, 'mslp')
            return self._data[varname]

        if varname == 'ws925':
            u925 = self.data(fhour, 'u925')
            v925 = self.data(fhour, 'v925')
            self._data[varname] = np.sqrt((u925 * u925) + (v925 * v925))
            logging.debug('{fhr:03} - {varname} : max:{max}, min:{min}'.format(
                fhr=fhour,
                varname=varname,
                max=np.max(self._data[varname]),
                min=np.min(self._data[varname])))
            return self._data[varname]

        if varname == 'vor':
            u850 = self.data(fhour, 'u850')
            v850 = self.data(fhour, 'v850')
            dx, dy = mpcalc.lat_lon_grid_deltas(self.data(fhour, 'lon1d'),
                                                self.data(fhour, 'lat1d'))
            vor = mpcalc.vorticity(u850, v850, dx, dy, dim_order='yx').magnitude * 10**5  # noqa pylint: disable=E1123, E731
            self._data[varname] = vor
            logging.debug('{fhr:03} - {varname} : max:{max}, min:{min}'.format(
                fhr=fhour,
                varname=varname,
                max=np.max(self._data[varname][180]),
                min=np.min(self._data[varname][180])))
            return self._data[varname]

        if varname == 'thck':
            gh850 = self.data(fhour, 'gh850')
            gh250 = self.data(fhour, 'gh250')
            self._data[varname] = gh250 - gh850
            logging.debug('{fhr:03} - {varname} : max:{max}, min:{min}'.format(
                fhr=fhour,
                varname=varname,
                max=np.max(self._data[varname]),
                min=np.min(self._data[varname])))
            return self._data[varname]

        raise ValueError("{varname} not recognised".format(varname=varname))

    def calc_natl_B_parameters(self, fh     , y     , x     )                         :
        cape = self.data(fh, 'cape')
        pmin = self.data(fh, 'pmin')
        lat = self.data(fh, 'lat1d')
        capeavg = np.mean(subset_grid(cape, y, x, self.deg5box))

        B48 = 0.8900867 - (0.0256533 * fh)
        B120 = -1.880649 + (0.0011505 * capeavg)
        B168 = -98.17343449 - (0.15732243 * lat[y]) + (0.09715203 * pmin / 100)
        return B48, B120, B168

    def calc_epac_B_parameters(self, fh     , y     , x     )                         :
        rh600avg = np.mean(subset_grid(self.data(fh, 'rh600'), y, x, self.deg5box))
        capeavg = np.mean(subset_grid(self.data(fh, 'cape'), y, x, self.deg5box))

        B48 = 0.001593571 - (0.038912763 * fh) + (0.002013083 * capeavg)
        B120 = -6.58554986 + (0.001894241 * capeavg) + (0.054472663 * rh600avg)
        B168 = -4.558516018 + (0.001943481 * capeavg) + (0.011236631 * fh)

        return B48, B120, B168


class CMCDefinition(ModelDefinition):
    def data(self, fhour     , varname     )        :
        if (varname in self._data) and (fhour == self._data_fhr):
            return self._data[varname]

        if self._data_fhr is None:
            self._data_fhr = fhour

        if fhour != self._data_fhr:
            self._data = {}
            self._data_fhr = fhour

        short_name_to_gribkwargs = {
            'mslp': {
                'shortName': 'msl',
            },
            'gh250': {
                'shortName': 'gh',
                'level': 250
            },
            'gh850': {
                'shortName': 'gh',
                'level': 850
            },
            'u925': {
                'shortName': 'u',
                'level': 925
            },
            'u850': {
                'shortName': 'u',
                'level': 850
            },
            'v925': {
                'shortName': 'v',
                'level': 925
            },
            'v850': {
                'shortName': 'v',
                'level': 850
            },
            # end of common variables
            'rh700': {
                'shortName': 'r',
                'level': 700
            },
            't1000': {
                'shortName': 't',
                'level': 1000
            },
            't700': {
                'shortName': 't',
                'level': 700
            },
            'gh1000': {
                'shortName': 'gh',
                'level': 1000
            },
            'gh700': {
                'shortName': 'gh',
                'level': 700
            },
        }

        grib_kwargs = short_name_to_gribkwargs.get(varname, None)
        if grib_kwargs is not None:
            return self.read_grib(fhour, varname, grib_kwargs, flip_lat=False)

        if (varname == 'lon1d') or (varname == 'lat1d'):
            if varname not in self._data:
                _ = self.data(fhour, 'mslp')
            return self._data[varname]

        if varname == 'ws925':
            u925 = self.data(fhour, 'u925')
            v925 = self.data(fhour, 'v925')
            self._data[varname] = np.sqrt((u925 * u925) + (v925 * v925))
            return self._data[varname]

        if varname == 'vor':
            u850 = self.data(fhour, 'u850')
            v850 = self.data(fhour, 'v850')
            dx, dy = mpcalc.lat_lon_grid_deltas(self.data(fhour, 'lon1d'),
                                                self.data(fhour, 'lat1d'))
            vor = mpcalc.vorticity(u850, v850, dx, dy, dim_order='yx').magnitude * 10**5  # noqa pylint: disable=E1123, E731
            self._data[varname] = vor
            return self._data[varname]

        if varname == 'thck':
            gh850 = self.data(fhour, 'gh850')
            gh250 = self.data(fhour, 'gh250')
            self._data[varname] = gh250 - gh850
            return self._data[varname]

        if varname == 'lapse':
            z700 = self.data(fhour, 'gh700')
            z1000 = self.data(fhour, 'gh1000')
            t700 = self.data(fhour, 't700')
            t1000 = self.data(fhour, 't1000')
            lapse = ((t700 - t1000) / (z700 - z1000)) * -1000.
            self._data[varname] = lapse
            return self._data[varname]

        raise ValueError("{varname} not recognised".format(varname=varname))

    def calc_natl_B_parameters(self, fh     , y     , x     )                         :
        rh7 = self.data(fh, 'rh700')
        thmax = self.data(fh, 'thmax')
        lon1d = self.data(fh, 'lon1d')
        rh7avg = np.mean(subset_grid(rh7, y, x, self.deg5box))

        B48 = -138.61238982 - (0.02995572 * fh) + (0.01463614 * thmax)
        B120 = -70.587026869 - (0.008904298 * fh) + (0.0007159913 * thmax) + (0.023088343 *
                                                                              rh7avg)
        B168 = 14.44851 - (0.00001181653 * lon1d[x]**3) + (0.000001956435 *
                                                           (lon1d[x]**3) * np.log(lon1d[x]))
        return B48, B120, B168

    def calc_epac_B_parameters(self, fh     , y     , x     )                  :
        rh700 = self.data(fh, 'rh700')
        lapse = self.data(fh, 'lapse')  # ((t700 - t1000) / (z700 - z1000)) * -1000.

        ci = np.mean(subset_grid(lapse, y, x, self.deg5box))
        rh7avg = np.mean(subset_grid(rh700, y, x, self.deg5box))
        rh7max = np.max(subset_grid(rh700, y, x, self.deg5box))
        rh7pert = rh7max - rh7avg

        B48 = -9.39795675 - (0.02069718 * fh) + (1.64429686 * ci)
        _fh = np.max([fh, 6])  # limit calculation to fh >= 6
        B120 = -21.066118 + (3.2084092 * np.sqrt(_fh)) - (
            0.553976 * np.sqrt(_fh) * np.log(_fh)) + (0.0682341 * rh7avg) + (1.4274026 * ci)
        B168 = -1.0463184 - (0.0653109 * rh7pert)

        return B48, B120, B168


class ECMDefinition(ModelDefinition):
    def filename(self, fhr     )       :
        valid_time = self.rundate + timedelta(hours=fhr)
        if fhr == 0:
            valid_time = self.rundate + timedelta(minutes=1)
        return self.fname_template.format(date=self.rundate, fhr=fhr, valid_time=valid_time)

    def data(self, fhour     , varname     )        :
        if (varname in self._data) and (fhour == self._data_fhr):
            return self._data[varname]

        if self._data_fhr is None:
            self._data_fhr = fhour

        if fhour != self._data_fhr:
            self._data = {}
            self._data_fhr = fhour

        short_name_to_gribkwargs = {
            'mslp': {
                'shortName': 'msl',
            },
            'gh250': {
                'shortName': 'gh',
                'level': 250
            },
            'gh850': {
                'shortName': 'gh',
                'level': 850
            },
            'u925': {
                'shortName': 'u',
                'level': 925
            },
            'u850': {
                'shortName': 'u',
                'level': 850
            },
            'v925': {
                'shortName': 'v',
                'level': 925
            },
            'v850': {
                'shortName': 'v',
                'level': 850
            },
            # end of common variables
            'rh700': {
                'shortName': 'r',
                'level': 700
            },
        }

        grib_kwargs = short_name_to_gribkwargs.get(varname, None)
        if grib_kwargs is not None:
            return self.read_grib(fhour, varname, grib_kwargs, flip_lat=True)

        if (varname == 'lon1d') or (varname == 'lat1d'):
            if varname not in self._data:
                _ = self.data(fhour, 'mslp')
            return self._data[varname]

        if varname == 'ws925':
            u925 = self.data(fhour, 'u925')
            v925 = self.data(fhour, 'v925')
            self._data[varname] = np.sqrt((u925 * u925) + (v925 * v925))
            return self._data[varname]

        if varname == 'vor':
            u850 = self.data(fhour, 'u850')
            v850 = self.data(fhour, 'v850')
            dx, dy = mpcalc.lat_lon_grid_deltas(self.data(fhour, 'lon1d'),
                                                self.data(fhour, 'lat1d'))
            vor = mpcalc.vorticity(u850, v850, dx, dy, dim_order='yx').magnitude * 10**5  # noqa pylint: disable=E1123, E731
            self._data[varname] = vor
            return self._data[varname]

        if varname == 'thck':
            gh850 = self.data(fhour, 'gh850')
            gh250 = self.data(fhour, 'gh250')
            self._data[varname] = gh250 - gh850
            return self._data[varname]

        raise ValueError("{varname} not recognised".format(varname=varname))

    def calc_natl_B_parameters(self, fh     , y     , x     )                         :
        lat1d = self.data(fh, 'lat1d')
        _fh = np.max([fh, 6])  # limit calculation to fh >= 6

        B48 = 1.75210835 - (0.03068216 * fh)
        B120 = -4.04742679 + (0.23514675 * _fh) - (0.04361315 * _fh * np.log(_fh))
        B168 = -2.47137493 + (0.01664906 * fh) - (0.08487111 * lat1d[y])

        return B48, B120, B168

    def calc_epac_B_parameters(self, fh     , y     , x     )                         :
        lat1d = self.data(fh, 'lat1d')
        rh700 = self.data(fh, 'rh700')
        rh7avg = np.mean(subset_grid(rh700, y, x, self.deg5box))

        B48 = 1.60378303 - (0.02585508 * fh)
        B120 = -3.42303304 + (0.03809354 * rh7avg)
        B168 = -2.68929248 + (0.02009218 * fh) - (0.09296465 * lat1d[y])

        return B48, B120, B168


class UKMDefinition(ModelDefinition):
    @property
    def f_hours(self, ):
        return [0, 6, 12, 18, 24, 30, 36, 42, 48, 54, 60, 72, 84, 96]

    def data(self, fhour     , varname     )        :
        if (varname in self._data) and (fhour == self._data_fhr):
            return self._data[varname]

        if self._data_fhr is None:
            self._data_fhr = fhour

        if fhour != self._data_fhr:
            self._data = {}
            self._data_fhr = fhour

        short_name_to_gribkwargs = {
            'mslp': {
                'shortName': 'prmsl',
            },
            'gh250': {
                'shortName': 'gh',
                'level': 250
            },
            'gh850': {
                'shortName': 'gh',
                'level': 850
            },
            'u925': {
                'shortName': 'u',
                'level': 925
            },
            'u850': {
                'shortName': 'u',
                'level': 850
            },
            'v925': {
                'shortName': 'v',
                'level': 925
            },
            'v850': {
                'shortName': 'v',
                'level': 850
            },
            # end of common variables
            'rh700': {
                'shortName': 'r',
                'level': 700
            },
        }

        grib_kwargs = short_name_to_gribkwargs.get(varname, None)
        if grib_kwargs is not None:
            logging.info("Reading data from {filepath}".format(self.filepath(fhr=fhour)))
            scale = 100 if varname == "mslp" else None
            return self.read_grib(fhour, varname, grib_kwargs, flip_lat=False, scale=scale)

        if (varname == 'lon1d') or (varname == 'lat1d'):
            if varname not in self._data:
                _ = self.data(fhour, 'mslp')
            return self._data[varname]

        if varname == 'ws925':
            u925 = self.data(fhour, 'u925')
            v925 = self.data(fhour, 'v925')
            self._data[varname] = np.sqrt((u925 * u925) + (v925 * v925))
            return self._data[varname]

        if varname == 'vor':
            u850 = self.data(fhour, 'u850')
            v850 = self.data(fhour, 'v850')
            dx, dy = mpcalc.lat_lon_grid_deltas(self.data(fhour, 'lon1d'),
                                                self.data(fhour, 'lat1d'))
            vor = mpcalc.vorticity(u850, v850, dx, dy, dim_order='yx').magnitude * 10**5  # noqa pylint: disable=E1123, E731
            self._data[varname] = vor
            return self._data[varname]

        if varname == 'thck':
            gh850 = self.data(fhour, 'gh850')
            gh250 = self.data(fhour, 'gh250')
            self._data[varname] = gh250 - gh850
            return self._data[varname]

        raise ValueError("{varname} not recognised".format(varname=varname))

    def calc_natl_B_parameters(self, fh     , y     , x     )                         :
        lat1d = self.data(fh, 'lat1d')
        _fh = np.max([fh, 6])  # limit calculation to fh >= 6

        B48 = 1.48780513 - (0.03959059 * fh)
        B120 = -3.24102228 + (0.33487425 * _fh) - (0.0655981 * _fh *
                                                   np.log(_fh)) - (0.08108531 * lat1d[y])
        B168 = -0.3103372 + (0.0153531 * fh) - (0.1962274 * lat1d[y])
        return B48, B120, B168

    def calc_epac_B_parameters(self, fh     , y     , x     )                         :
        lat1d = self.data(fh, 'lat1d')
        wsmax = self.data(fh, 'wsmax')
        _fh = np.max([fh, 6])  # limit calculation to fh >= 6

        B48 = -2.73565789 - (0.03587089 * fh) + (0.27783204 * lat1d[y])
        B120 = -6.9776412459 + (0.0023649661 * _fh * _fh) - (
            0.0004762703 * _fh * _fh * np.log(_fh)) + (0.1964929968 *
                                                       lat1d[y]) + (0.1038416607 * wsmax)
        B168 = -3.37351112 + (0.01374208 * fh)

        return B48, B120, B168


class NAVDefinition(ModelDefinition):
    def data(self, fhour     , varname     )        :
        if (varname in self._data) and (fhour == self._data_fhr):
            return self._data[varname]

        if self._data_fhr is None:
            self._data_fhr = fhour

        if fhour != self._data_fhr:
            self._data = {}
            self._data_fhr = fhour

        short_name_to_gribkwargs = {
            'mslp': {
                'shortName': 'prmsl',
            },
            'gh250': {
                'shortName': 'gh',
                'level': 250
            },
            'gh850': {
                'shortName': 'gh',
                'level': 850
            },
            'u925': {
                'shortName': 'u',
                'level': 925
            },
            'u850': {
                'shortName': 'u',
                'level': 850
            },
            'v925': {
                'shortName': 'v',
                'level': 925
            },
            'v850': {
                'shortName': 'v',
                'level': 850
            },
            # end of common variables
            'rh700': {
                'shortName': 'r',
                'level': 700
            },
        }

        grib_kwargs = short_name_to_gribkwargs.get(varname, None)
        if grib_kwargs is not None:
            logging.info("Reading data from {}".format(self.filepath(fhr=fhour)))
            scale = 100 if varname == "mslp" else None
            fix_coords = True if 'lat1d' not in self._data else False
            _ = self.read_grib(fhour, varname, grib_kwargs, scale=scale)
            if fix_coords:
                lat1d = self._data['lat1d']
                lon1d = self._data['lon1d']

                latdiff = lat1d[1] - lat1d[0]
                londiff = lon1d[1] - lon1d[0]

                self._data['lat1d'] = lat1d / latdiff / 2
                self._data['lon1d'] = lon1d / londiff / 2 + 23.5926
                self._latdiff = self._data['lat1d'][1] - self._data['lat1d'][0]
                self._londiff = self._data['lon1d'][1] - self._data['lon1d'][0]
            return self._data[varname]

        if (varname == 'lon1d') or (varname == 'lat1d'):
            if varname not in self._data:
                _ = self.data(fhour, 'mslp')
            return self._data[varname]

        if varname == 'ws925':
            u925 = self.data(fhour, 'u925')
            v925 = self.data(fhour, 'v925')
            self._data[varname] = np.sqrt((u925 * u925) + (v925 * v925))
            return self._data[varname]

        if varname == 'vor':
            u850 = self.data(fhour, 'u850')
            v850 = self.data(fhour, 'v850')
            dx, dy = mpcalc.lat_lon_grid_deltas(self.data(fhour, 'lon1d'),
                                                self.data(fhour, 'lat1d'))
            vor = mpcalc.vorticity(u850, v850, dx, dy, dim_order='yx').magnitude * 10**5  # noqa pylint: disable=E1123, E731
            self._data[varname] = vor
            return self._data[varname]

        if varname == 'thck':
            gh850 = self.data(fhour, 'gh850')
            gh250 = self.data(fhour, 'gh250')
            self._data[varname] = gh250 - gh850
            return self._data[varname]

        raise ValueError("{varname} not recognised".format(varname=varname))

    def calc_natl_B_parameters(self, fh     , y     , x     )                         :
        rh7 = self.data(fh, 'rh700')
        rh7_subset = subset_grid(rh7, y, x, self.deg5box)
        rh7pert = np.max(rh7_subset) - np.mean(rh7_subset)
        thmax = self.data(fh, 'thmax')

        B48 = -119.06409326 - (0.03690551 * fh) + (0.01271121 * thmax)
        B120 = -1.035610445 - (0.031858673 * rh7pert) + (0.004873447 * fh)
        B168 = -4.29567898 - (0.08242899 * rh7pert) + (0.0283467 * fh)
        return B48, B120, B168

    def calc_epac_B_parameters(self, fh     , y     , x     )                         :
        rh7 = self.data(fh, 'rh700')
        rh7_subset = subset_grid(rh7, y, x, self.deg5box)
        rh7pert = np.max(rh7_subset) - np.mean(rh7_subset)
        pmin = self.data(fh, 'pmin')
        _fh = np.max([fh, 6])  # limit calculation to fh >= 6

        B48 = 288.64793884 - (0.03378358 * _fh) - (0.28535942 * pmin / 100)
        B120 = -1.288778 + (0.0004799016 * _fh * _fh) - (0.000002834551 *
                                                         _fh**3) - (0.03034144 * rh7pert)
        B168 = -2.475415 + (11.70829 * _fh**-0.5) + (0.0000009045917 * _fh**3) - (0.08280565 *
                                                                                  rh7pert)

        return B48, B120, B168


READERS = {
    'gfs': GFSDefinition,
    'cmc': CMCDefinition,
    'ecm': ECMDefinition,
    'ukm': UKMDefinition,
    'nav': NAVDefinition,
}
