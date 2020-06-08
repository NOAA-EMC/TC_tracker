import datetime
import logging

import numpy as np
import scipy.ndimage as ndi

from genesis_guidance import forecast_models


def local_minima(data            , footprint      = 3)              :
    minima = ndi.minimum_filter(data, size=footprint)
    min_mask = minima == data
    return np.transpose(np.nonzero(min_mask))


def search_for_object(fh, model_definition                                 ,
                      valid_time                   , rundate                   ):
    lon1d = model_definition.data(fh, 'lon1d')
    lat1d = model_definition.data(fh, 'lat1d')
    modelnum = model_definition.model_num
    vtstr = datetime.datetime.strftime(valid_time, '%Y%m%d%H')

    # Define basin domain
    basin_bbox = model_definition.basin_bbox()

    latmin = basin_bbox['latmin']
    latmax = basin_bbox['latmax']
    lonmin = basin_bbox['lonmin']
    lonmax = basin_bbox['lonmax']

    xmin = np.abs(lon1d - lonmin).argmin()
    xmax = np.abs(lon1d - lonmax).argmin()
    ymin = np.abs(lat1d - latmin).argmin()
    ymax = np.abs(lat1d - latmax).argmin()

    allpinfo, alltcinfo = None, None
    yx = local_minima(model_definition.data(fh, 'mslp')[ymin:ymax + 1, xmin:xmax + 1])

    logging.info('{basin}:{fh:03} found {lenyx} mslp minima '.format(
        lenyx=len(yx), fh=fh, basin=model_definition.basin))
    # for y, x in np.transpose(yx):
    for y, x in yx:
        x += xmin
        y += ymin

        _ymin = ymin
        _ymax = ymax
        # natl bound nudging
        if lon1d[x] <= 275 and model_definition.basin == 'natl':
            _ymin = np.abs(lat1d - 14.).argmin()
            _ymax = np.abs(lat1d - 41.).argmin()
        if lon1d[x] <= 270 and model_definition.basin == 'natl':
            _ymin = np.abs(lat1d - 17.).argmin()
            _ymax = np.abs(lat1d - 41.).argmin()

        # epac bound nudging
        if lon1d[x] >= 260 and model_definition.basin == 'epac':
            _ymax = np.abs(lat1d - 15.).argmin()
        if lon1d[x] >= 270 and model_definition.basin == 'epac':
            _ymin = np.abs(lat1d - 13.).argmin()

        if _ymin < y < _ymax:
            criteria, minmax_data = model_definition.check_minmax_criteria(fh, y, x)
            if criteria:
                pmin, vmax, thmax, wsmax = minmax_data
                model_definition._data['pmin'] = pmin
                model_definition._data['vmax'] = vmax
                model_definition._data['thmax'] = thmax
                model_definition._data['wsmax'] = wsmax

                # Calculate any quantities needed for logistic regression
                # equations and calculate the 48 and 120 h genesis
                # probabilities
                B48, B120, B168 = model_definition.calc_B_parameters(fh=fh, y=y, x=x)

                pg48 = (1 / (1 + (1 / np.exp(B48))))
                pg120 = (1 / (1 + (1 / np.exp(B120))))
                pg168 = (1 / (1 + (1 / np.exp(B168))))

                png48 = 1 - pg48
                png120 = 1 - pg120
                png168 = 1 - pg168

                prob48 = pg48 * 100
                prob120 = (1 - (png48 * png120)) * 100
                prob168 = (1 - (png48 * png120 * png168)) * 100

                pinfo = np.array([
                    '{:%Y%m%d%H}'.format(rundate), '{:03}'.format(fh), vtstr, pmin / 100,
                    lat1d[y], lon1d[x], vmax, thmax, wsmax, prob48, prob120, prob168, modelnum
                ])

                # For high-resolution model output, do not count MSLP minima
                # more than once
                foundmatch = 0
                if allpinfo is None:
                    allpinfo = pinfo
                else:
                    if allpinfo.ndim == 1:
                        if (abs(float(pinfo[4]) - float(allpinfo[4])) < 2.5
                                and abs(float(pinfo[5]) - float(allpinfo[5])) < 2.5
                                and int(pinfo[1]) == int(allpinfo[1])):
                            foundmatch = 1
                    else:
                        nlines = allpinfo.shape[0]
                        for q in range(nlines):
                            if (abs(float(pinfo[4]) - float(allpinfo[q, 4])) < 2.5
                                    and abs(float(pinfo[5]) - float(allpinfo[q, 5])) < 2.5
                                    and int(pinfo[1]) == int(allpinfo[q, 1])):
                                foundmatch = 1
                    if foundmatch != 0:
                        logging.debug('{basin}:{fh:03} Cyclone Found Already'.format(
                            basin=model_definition.basin,
                            fh=fh,
                        ))
                    if foundmatch < 1:
                        allpinfo = np.vstack((allpinfo, pinfo))

                if (vmax > model_definition.vthresh and thmax > model_definition.ththresh
                        and wsmax > model_definition.wsthresh and foundmatch < 1):
                    tcinfo = np.array([
                        '{:%Y%m%d%H}'.format(rundate), '{:03}'.format(fh), vtstr, pmin / 100,
                        lat1d[y], lon1d[x], vmax, thmax, wsmax, prob48, prob120, prob168,
                        modelnum
                    ])
                    if alltcinfo is None:
                        alltcinfo = tcinfo
                    else:
                        alltcinfo = np.vstack((alltcinfo, tcinfo))
    if alltcinfo is not None:
        logging.info('{basin}:{fh:03} found {lentc} Storms'.format(
            basin=model_definition.basin, fh=fh, lentc=len(alltcinfo)))
    if allpinfo is not None:
        logging.info('{basin}:{fh:03} found {lentc} Disturbances'.format(
            basin=model_definition.basin, fh=fh, lentc=len(allpinfo)))

    return allpinfo, alltcinfo


def dist_match(tcinfo, tdiff_crit=3, distdiff_crit=3):
    if tcinfo is None:
        return

    if tcinfo.ndim == 1:
        tcinfo = tcinfo[np.newaxis, :]

    tcinfo = tcinfo.astype('float')

    storm_id = 1
    n = 0
    nlines = tcinfo.shape[0]
    while nlines > 0:
        # Get info for first line in file.
        n = 0
        a = [n]
        logging.info("n={n}, tcinfo:{shape}".format(n=n, shape=tcinfo.shape))
        nline = tcinfo[n, :]
        nfhr = int(nline[1])
        nlat = nline[4]
        nlon = nline[5]
        while n < nlines:
            # Get info for subsequent lines in file
            xline = tcinfo[n, :]
            xfhr = int(xline[1])
            xlat = xline[4]
            xlon = xline[5]
            tdiff = xfhr - nfhr
            latdiff = abs(nlat - xlat)
            londiff = abs(nlon - xlon)
            # If subsequent line is 6 h later and within 3 deg lat/lon
            # of first line, classify as same system, and set
            # subsequent line to be new "first" line.
            if (tdiff != 0 and tdiff <= tdiff_crit and latdiff <= distdiff_crit
                    and londiff <= distdiff_crit):
                a.append(n)
                # nline = xline
                nfhr = xfhr
                nlat = xlat
                nlon = xlon
            n = n + 1

        yield storm_id, tcinfo[a, :]

        # Remove all lines that were used in classifying above disturbance,
        # and repeat using new first line in file.
        tcinfo = np.delete(tcinfo, a, axis=0)
        nlines = tcinfo.shape[0]
        storm_id = storm_id + 1
