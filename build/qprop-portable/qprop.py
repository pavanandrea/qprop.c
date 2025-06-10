#-------------------------------------------------------------------------------
#   A Python wrapper for qprop.c
#
#   How to import:
#   import sys
#   sys.path.insert(0, "path/to/bin/qprop/")
#   import qprop
#
#   Author: Andrea Pavan
#   License: MIT
#-------------------------------------------------------------------------------
import ctypes
import os
import platform

#import precompiled shared library for the current operating system
lib_filename = ""
current_folder = os.path.dirname(os.path.abspath(__file__))
if platform.system() == "Windows":
    lib_filename = os.path.join(current_folder, "qprop-lib-windows-x64.dll")
elif platform.system() == "Darwin":
    lib_filename = os.path.join(current_folder, "qprop-lib-macos-arm64.dylib")
elif platform.system() == "Linux":
    lib_filename = os.path.join(current_folder, "qprop-lib-linux-x64.so")
else:
    print("ERROR in qprop.py: the provided binaries do not support the current operating system")
lib = ctypes.CDLL(lib_filename)



#----------------------
#   DATA STRUCTURES
#----------------------


#data structure for polars
class Polar(ctypes.Structure):
    _fields_ = [
        ("Re", ctypes.c_double),
        ("alpha", ctypes.POINTER(ctypes.c_double)),
        ("CL", ctypes.POINTER(ctypes.c_double)),
        ("CD", ctypes.POINTER(ctypes.c_double)),
        ("size", ctypes.c_int)
    ]

# data structure for airfoils
class Airfoil(ctypes.Structure):
    _fields_ = [
        ("polars", ctypes.POINTER(Polar)),
        ("size", ctypes.c_int)
    ]

# data structure for blade elements
class Section(ctypes.Structure):
    _fields_ = [
        ("c", ctypes.c_double),
        ("beta", ctypes.c_double),
        ("r", ctypes.c_double),
        ("airfoil", Airfoil)
    ]

# data structure for rotors
class Rotor(ctypes.Structure):
    _fields_ = [
        ("D", ctypes.c_double),
        ("B", ctypes.c_int),
        ("nsections", ctypes.c_int),
        ("sections", ctypes.POINTER(Section))
    ]

# data structure for qprop output
class RotorPerformance(ctypes.Structure):
    _fields_ = [
        ("T", ctypes.c_double),
        ("Q", ctypes.c_double),
        ("CT", ctypes.c_double),
        ("CP", ctypes.c_double),
        ("J", ctypes.c_double),
        ("residuals", ctypes.POINTER(ctypes.c_double)),
        ("Gamma", ctypes.POINTER(ctypes.c_double)),
        ("lambdaw", ctypes.POINTER(ctypes.c_double)),
        ("r", ctypes.POINTER(ctypes.c_double)),
        ("W", ctypes.POINTER(ctypes.c_double)),
        ("phi", ctypes.POINTER(ctypes.c_double)),
        ("dTdr", ctypes.POINTER(ctypes.c_double)),
        ("dQdr", ctypes.POINTER(ctypes.c_double)),
        ("nelems", ctypes.c_int)
    ]



#----------------------------
#   FUNCTION DECLARATIONS
#----------------------------


def create_polar(Re, alpha, CL, CD, size):
    """
    CREATE_POLAR creates a Polar object from Python lists
    Input:
        - Re: Reynolds number
        - alpha: array of angle of attacks (rad)
        - CL: array of lift coefficients - same size as alpha
        - CD: array of drag coefficients - same size as alpha
        - size: number of points in the polar
    Output:
        - (Polar): data structure containing the polar data
    """
    newpolar = Polar()
    newpolar.Re = Re
    newpolar.alpha = (ctypes.c_double * size)(*alpha)
    newpolar.CL = (ctypes.c_double * size)(*CL)
    newpolar.CD = (ctypes.c_double * size)(*CD)
    newpolar.size = size
    return newpolar


def create_airfoil(polars, size):
    """
    CREATE_AIRFOIL creates an Airfoil object from Python lists
    Input:
        - polars: array of polars - typically at different Re
        - size: number of polars in the airfoil
    Output:
        - (Airfoil): data structure containing the specified airfoil polars
    """
    newairfoil = Airfoil()
    newairfoil.polars = (Polar * size)(*polars)
    newairfoil.size = size
    return newairfoil


def create_section(c, beta, r, airfoil):
    """
    CREATE_SECTION creates a Section object from Python lists
    Input:
        - c: chord length (m)
        - beta: twist angle (rad)
        - r: radial distance (m)
        - airfoil (Airfoil): local airfoil data
    Output:
        - (Element): data structure containing the element data
    """
    newsection = Section()
    newsection.c = c
    newsection.beta = beta
    newsection.r = r
    newsection.airfoil = airfoil
    return newsection


def create_rotor(D, B, nsections, sections):
    """
    CREATE_ROTOR creates a Rotor object from Python lists
    Input:
        - D: rotor diameter (m)
        - B: number of blades
        - nsections: number of sections discretizing a blade
        - sections: array of sections discretizing a blade
    Output:
        - (Rotor): qprop-compatible data structure containing the desired rotor geometry
    """
    newrotor = Rotor()
    newrotor.D = D
    newrotor.B = B
    newrotor.nsections = nsections
    newrotor.sections = (Section * nsections)(*sections)
    return newrotor


lib.deg2rad.argtypes = [ctypes.c_double]
lib.deg2rad.restype = ctypes.c_double
def deg2rad(deg):
    """
    DEG2RAD converts degrees to radians
    Input:
        - deg (double): angle in degrees
    Output:
        - (double): angle in radians
    Example:
        myangle = deg2rad(+45.0)
    """
    return lib.deg2rad(deg)


lib.read_xfoil_polar_from_file.argtypes = [ctypes.c_char_p]
lib.read_xfoil_polar_from_file.restype = ctypes.POINTER(Polar)
def read_xfoil_polar_from_file(filename):
    """
    READ_XFOIL_POLAR_FROM_FILE reads an airfoil polar from a text file
    Input:
        - filename: name of the txt file containing the polar data
    Output:
        - (Polar): data structure containing the polar data
    Notes:
        - The file is assumed to be in the XFoil/XFLR5 format:
            - Reynolds number on a line containing "Re =", ignoring spaces
            - A table of alpha, CL and CD values, ordered by alpha (from min to max)
            - Alpha values in the first column, CL in the second and CD in the third
            - No empty lines between values in the table
        - The file content is not thoroughly checked for errors
        - This function internally allocates memory for the Polar structure arrays
          alpha, CL and CD using malloc and realloc.
          It is the caller's responsibility to free this memory by calling
          unload_polar_from_memory(Polar) when it is no longer needed
    Example:
        mypolar = read_xfoil_polar_from_file("naca4412_Re0.030_M0.00_N6.0.txt")
    """
    return lib.read_xfoil_polar_from_file(filename.encode()).contents


lib.free_polar.argtypes = [ctypes.POINTER(Polar)]
lib.free_polar.restype = None
def free_polar(currentpolar):
    """
    FREE_POLAR frees the memory allocated in a Polar structure
    Input:
        - currentpolar (Polar): object that is no longer needed
    Output:
        - none
    """
    lib.free_polar(ctypes.byref(currentpolar))


lib.free_airfoil.argtypes = [ctypes.POINTER(Airfoil)]
lib.free_airfoil.restype = None
def free_airfoil(currentairfoil):
    """
    FREE_AIRFOIL frees the memory allocated in an Airfoil structure
    Input:
        - currentairfoil (Airfoil): object that is no longer needed
    Output:
        - none
    """
    lib.free_airfoil(ctypes.byref(currentairfoil))


lib.import_xfoil_polars.argtypes = [ctypes.POINTER(ctypes.c_char_p), ctypes.c_int]
lib.import_xfoil_polars.restype = ctypes.POINTER(Airfoil)
def import_xfoil_polars(filenames):
    """
    IMPORT_XFOIL_POLARS imports airfoil polars from multiple text files
    Input:
        - filenames: list of files containing polar data
    Output:
        - (Airfoil): data structure containing the imported airfoil polars
    Notes:
        - All files are assumed to be in the XFoil/XFLR5 format
          (see the notes above "read_xfoil_polar_from_file")
        - Safety checks on user input are not implemented yet
        - The content of each file is not checked
        - This function internally allocates memory for the Airfoil structure arrays
          and for each Polar using malloc and realloc.
          It is the caller's responsibility to free this memory when it is no longer
          needed, by calling unload_airfoil_from_memory(Airfoil)
    Example:
        filenames = ["naca4412_Re0.030_M0.00_N6.0.txt", "naca4412_Re0.060_M0.00_N6.0.txt"]
        myairfoil = import_xfoil_polars(filenames)
    """
    filenames_array = (ctypes.c_char_p * len(filenames)) (*[filename.encode() for filename in filenames])
    return lib.import_xfoil_polars(filenames_array, len(filenames)).contents


lib.analytic_polar_curves.argtypes = [ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_double,
                                    ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_double,
                                    ctypes.c_double, ctypes.c_double]
lib.analytic_polar_curves.restype = ctypes.POINTER(Airfoil)
def analytic_polar_curves(CL0, CL_a, CLmin, CLmax, CD0, CD2u, CD2l, CLCD0, REref, REexp):
    """
    ANALYTIC_POLAR_CURVES generates polars using the simple analytic model
    described by Drela in the QPROP user guide
    Input:
        - CL0: zero-lift lift coefficient
        - CL_a: lift curve slope
        - CLmin: minimum lift coefficient
        - CLmax: maximum lift coefficient
        - CD0: zero-lift drag coefficient
        - CD2u: quadratic coefficient in the drag formula
        - CD2l: quadratic coefficient in the drag formula
        - CLCD0: lift coefficient at minimum drag
        - REref: reference Reynolds number for all the coefficients above
        - REexp: Reynolds number exponent (default: -0.5)
    Output:
        - (Airfoil): generated polar curves
    Example:
        myairfoil = analytic_polar_curves(0.50, 5.8, -0.3, 1.2, 0.028, 0.050, 0.020, 0.5, 70000, -0.7)
    """
    return lib.analytic_polar_curves(CL0, CL_a, CLmin, CLmax, CD0, CD2u, CD2l, CLCD0, REref, REexp).contents


lib.import_rotor_geometry_apc.argtypes = [ctypes.c_char_p, ctypes.POINTER(Airfoil)]
lib.import_rotor_geometry_apc.restype = ctypes.POINTER(Rotor)
def import_rotor_geometry_apc(filename, airfoil):
    """
    IMPORT_ROTOR_GEOMETRY_APC reads a propeller geometry from an APC PE0 file
    Input:
        - filename (String): name of the PE0 file containing the geom data
        - airfoil (Airfoil): pointer to an airfoil
    Output:
        - (Rotor): imported rotor geometry with the given airfoil
    Notes:
        - the file is assumed to be downloaded from the official APC website
    Example:
        airfoil_filenames = ["naca4412_Re0.100_M0.00_N6.0.txt"]
        myairfoil = import_xfoil_polars(airfoil_filenames)
        myrotor = import_rotor_geometry_apc("10x7SF-PERF.PE0", myairfoil)
    """
    return lib.import_rotor_geometry_apc(filename.encode(), ctypes.byref(airfoil)).contents


lib.import_rotor_geometry_uiuc.argtypes = [ctypes.c_char_p, ctypes.POINTER(Airfoil), ctypes.c_double, ctypes.c_int]
lib.import_rotor_geometry_uiuc.restype = ctypes.POINTER(Rotor)
def import_rotor_geometry_uiuc(filename, airfoil, D, B):
    """
    IMPORT_ROTOR_GEOMETRY_UIUC reads a propeller geometry from an UIUC txt file
    Input:
        - filename (String): name of the txt file containing the geom data
        - airfoil (Airfoil): pointer to an airfoil
        - D: rotor diameter (m)
        - B: number of blades
    Output:
        - (Rotor): imported rotor geometry with the given properties
    Notes:
        - the file is assumed to be downloaded from the UIUC website
    Example:
        airfoil_filenames = ["naca4412_Re0.100_M0.00_N6.0.txt"]
        myairfoil = import_xfoil_polars(airfoil_filenames)
        myrotor = import_rotor_geometry_uiuc("apcsf_10x7_geom.txt", myairfoil, 10*0.0254, 2)
    """
    return lib.import_rotor_geometry_uiuc(filename.encode(), ctypes.byref(airfoil), D, B).contents


lib.refine_rotor_sections.argtypes = [ctypes.POINTER(Rotor), ctypes.c_int]
lib.refine_rotor_sections.restype = ctypes.POINTER(Rotor)
def refine_rotor_sections(oldrotor, nsections):
    """
    REFINE_ROTOR_SECTIONS creates a propeller geometry with the specified number
    of equally-spaced sections
    Input:
        - oldrotor (Rotor): reference rotor geometry
        - nsections: desired number of equally-spaced sections
    Output:
        - (Rotor): refined rotor geometry
    Example:
        airfoil_filenames = ["naca4412_Re0.100_M0.00_N6.0.txt"]
        myairfoil = import_xfoil_polars(airfoil_filenames)
        reference_rotor = import_rotor_geometry_uiuc("apcsf_10x7_geom.txt", myairfoil, 10*0.0254, 2)
        myrotor = refine_rotor_sections(reference_rotor, 100)
    """
    return lib.refine_rotor_sections(ctypes.byref(oldrotor), nsections).contents


lib.free_rotor.argtypes = [ctypes.POINTER(Rotor)]
lib.free_rotor.restype = None
def free_rotor(currentrotor):
    """
    FREE_ROTOR frees the memory allocated in a Rotor structure
    Input:
        - currentrotor (Rotor): object that is no longer needed
    Output:
        - none
    """
    lib.free_rotor(ctypes.byref(currentrotor))


lib.qprop.argtypes = [ctypes.POINTER(Rotor), ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_double, ctypes.c_double, ctypes.c_double]
lib.qprop.restype = ctypes.POINTER(RotorPerformance)
def qprop(rotor, Uinf, Omega, tol=1e-6, itmax=100, rho=1.225, mu=1.81e-5, a=0.0):
    """
    QPROP runs the QProp algorithm as described by Drela for each blade element
    Input:
        - rotor (Rotor): rotor geometry
        - Uinf: freestream velocity in m/s
        - Omega: rotor speed in rad/s
        - tol: stopping criterion tolerance (default: 1e-6)
        - itmax: maximum number of iterations (default: 100)
        - rho: air density in kg/m3 (default: 1.225)
        - mu: air dynamic viscosity in Pa-s (default: 1.81e-5)
        - a: speed of sound in m/s (default: 0.0) - set to 0 to disable Mach correction
    Output:
        - (RotorPerformance): data structure containing the QProp outputs
    Notes:
        - the current implementation assumes that there is no externally-induced
          tangential velocity (Ut = 0)
    """
    return lib.qprop(ctypes.byref(rotor), Uinf, Omega, tol, itmax, rho, mu, a).contents


lib.free_rotor_performance.argtypes = [ctypes.POINTER(RotorPerformance)]
lib.free_rotor_performance.restype = None
def free_rotor_performance(perf):
    """
    FREE_ROTOR_PERFORMANCE frees the memory allocated in a qprop output
    Input:
        - perf (RotorPerformance): qprop output object that is no longer needed
    Output:
        - none
    """
    lib.free_rotor_performance(ctypes.byref(perf))

