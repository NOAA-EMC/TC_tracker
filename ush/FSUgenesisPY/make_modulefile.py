import os

module_file = """#%Module

module-whatis "Sets environment for tclogg tracker"
module load python/3.6.3
prepend-path PATH {cwd}/bin
prepend-path PYTHONPATH {cwd}
prepend-path PYTHONPATH /usrx/local/prod/packages/python/3.6.3/lib/python3.6
"""

with open('modulefiles/tclogg', 'w') as f:
    f.write(module_file.format(cwd=os.getcwd()))
