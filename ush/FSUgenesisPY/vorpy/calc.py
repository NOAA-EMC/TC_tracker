import numpy as np


class Quantity(object):
    def __init__(self, values):
        self.magnitude = values


def vorticity(u, v, dx, dy, dim_order):
    """ Crippled version of metpy.calc.vorticity
        Small errors likely due to dx, dy calculations
    """
    du = np.gradient(u, axis=0)
    dv = np.gradient(v, axis=1)
    return Quantity(dv/dx - du/dy)


def lat_lon_grid_deltas(longitude, latitude, **kwargs):
    """ Crippled version of metpy function which barely does anything"""
    dx = np.gradient(longitude) * 111111
    dy = np.gradient(latitude) * 111111
    dxx, dyy = np.meshgrid(dx, dy, )
    dxx = dxx * np.cos(np.radians(latitude))[:, np.newaxis]

    return dxx, dyy
