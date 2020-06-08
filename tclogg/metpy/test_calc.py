import numpy as np
import metpy.calc
from metpy.units import units


def test_vort():
    u_grid = np.ones((361, 720), np.float32)
    v_grid = np.ones((361, 720), np.float32)
    latitude = np.linspace(-90, 90, 361)
    longitude = np.linspace(0, 359.5, 720)
    u_grid[90:110, :] = np.linspace(1, 5, 20)[:, np.newaxis]**2
    u_grid[110:130, :] = np.linspace(5, 1, 20)[:, np.newaxis]**2
    dx, dy = metpy.calc.lat_lon_grid_deltas(longitude, latitude)
    vor = metpy.calc.vorticity((u_grid * units.meter / units.second),
                               (v_grid * units.meter / units.second),
                               dx,
                               dy)
    vor = np.nan_to_num(vor.magnitude, 0)

    import py27.metpy.calc as terrible
    tdx, tdy = terrible.lat_lon_grid_deltas(longitude, latitude)
    tvor = terrible.vorticity(u_grid, v_grid, tdx, tdy)
    print((tvor - vor).max())
    # import matplotlib.pyplot as plt
    # plt.pcolormesh((tvor - vor))
    # plt.show()


def test_latlon_grid():
    latitude = np.linspace(-90, 90, 361)
    longitude = np.linspace(0, 359.5, 720)

    dx, dy = metpy.calc.lat_lon_grid_deltas(longitude, latitude)
    print(dx.max())
    print(dx.shape)
    print(dy.max())

    import py27.metpy.calc as terrible
    tdx, tdy = terrible.lat_lon_grid_deltas(longitude, latitude)

    print(tdx.max())
    print(tdx[:,:-1].shape)
    print(tdy.max())


    print(np.abs(tdx[:,:-1] - dx).max())
    print(np.abs(tdy[:-1,:] - dy).max())


if __name__ == "__main__":
    # test_latlon_grid()
    test_vort()
