"""
This here contains an abomination of a py2.7 work around.  We'll spoof the pygrib.open
function to work with ncepgrib2 on WCOSS.


pygrib open is used as a context manager, so will mock that interface and replicate the
.select() method to find the grib message based on shortName and level and return the
ncepgrib2 message, thankfully the ncepgrib2 message has both .values and .latlons().

ncepgrib2 doesn't utilise Grib Definitions so we'll define very basic mapping between
shortName and ProductTemplateDefinitions here but this will be massively restricted.
"""
from contextlib import contextmanager
import logging

import ncepgrib2


class gribfile(object):
    def __init__(self, filename):
        self.filename = filename
        self.msgs = ncepgrib2.Grib2Decode(filename)

    def get_msg(self, req_def, level=None):
        for _msg in self.msgs:
            _lev = _msg.product_definition_template[11] / 100.
            prod_def = _msg.product_definition_template[0]
            sub_def = _msg.product_definition_template[1]
            if prod_def == req_def[0] and sub_def == req_def[1]:
                if level is not None and _lev != level:
                    continue
                logging.debug(_msg)
                logging.debug(_msg.values)
                yield _msg

    @staticmethod
    def get_req_def(shortName):
        defs = {
            'mslet': [3, 192],
            'gh': [3, 5],
            'u': [2, 2],
            'v': [2, 3],
            'lhtfl': [0, 10],
            'r': [1, 1],
            'cape': [7, 6],
        }
        req_def = defs.get(shortName, None)
        if req_def is None:
            raise ValueError('{shortName} not found in definitions'.format(shortName))
        return req_def

    def select(self, shortName, level=None):
        req_def = self.get_req_def(shortName)
        msg = list(self.get_msg(req_def, level=level))
        return msg


def gaulats():
    raise NotImplementedError


@contextmanager
def open(filename):
    yield gribfile(filename)
