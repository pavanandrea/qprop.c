#-------------------------------------------------------------------------------
#   Testing script for the qprop.py binding
#
#   How to run:
#   python3 06a_test_python_binding.py
#
#   Author: Andrea Pavan
#   License: MIT
#-------------------------------------------------------------------------------
import os
import sys
sys.path.insert(0, "../build/qprop-portable/")
import qprop

def main():
    #test 1 - simple utilities
    myangle = qprop.deg2rad(+45.0)
    if abs(myangle - 0.7853981633974483) <= 1e-6:
        print("TEST 1 - PASSED :)")
    else:
        print("TEST 1 - FAILED :(")
        return
    
    #test 2 - import polar from file
    polar2 = qprop.read_xfoil_polar_from_file("02_airfoil_polar_FX63-120_Re0.300_M0.00_N9.0.txt")
    if polar2.Re == 300000 \
                and abs(polar2.alpha[2] - qprop.deg2rad(2.000)) <= 1e-6 \
                and abs(polar2.CL[0] - 0.8022) <= 1e-6 \
                and abs(polar2.CD[polar2.size-1] - 0.06283) <= 1e-6 \
                and polar2.size == 14:
        print("TEST 2 - PASSED :)")
    else:
        print("TEST 2 - FAILED :(")
        qprop.free_polar(polar2)
        return

    #test 3 - import airfoil from files
    filenames3 = [
        os.path.join("airfoil_polar_naca4412_Ncrit=6", f) \
        for f in os.listdir("airfoil_polar_naca4412_Ncrit=6") \
        if f.endswith(".txt")
    ]
    naca4412 = qprop.import_xfoil_polars(filenames3)
    if naca4412.size == 10 and naca4412.polars[0].alpha[0] == qprop.deg2rad(-15.0):
        print("TEST 3 - PASSED :)")
    else:
        print("TEST 3 - FAILED :(")
        qprop.free_polar(polar2)
        qprop.free_airfoil(naca4412)
        return

    #test 4 - analyze APC propeller at J=0.05
    apc10x7sf = qprop.import_rotor_geometry_apc(
        os.path.join("..","validation","apc_10x7sf","10x7SF-PERF.PE0"),
        naca4412
    )
    Uinf = 1.2729633333333334      #freestream velocity (m/s)
    Omega = 629.7846072896339      #rotor speed (rad/s)
    result4 = qprop.qprop(apc10x7sf, Uinf, Omega)
    if abs(result4.J - 0.05) <= 1e-6 \
                and abs(result4.T - 7.811303879404407) <= 1e-6 \
                and abs(result4.Q - 0.14308075154669447) <= 1e-6:
        print("TEST 4 - PASSED :)")
    else:
        print("TEST 4 - FAILED :(")
        qprop.free_polar(polar2)
        qprop.free_airfoil(naca4412)
        qprop.free_rotor(apc10x7sf)
        qprop.free_rotor_performance(result4)
        return

    #completed
    qprop.free_polar(polar2)
    qprop.free_airfoil(naca4412)
    qprop.free_rotor(apc10x7sf)
    qprop.free_rotor_performance(result4)

if __name__ == "__main__":
    main()

