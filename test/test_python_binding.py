#-------------------------------------------------------------------------------
#   Testing script for the qprop.py binding
#
#   How to run:
#   python3 test_python_binding.py
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
        print("TEST P1 - PASSED :)")
    else:
        print("TEST P1 - FAILED :(")
        return
    
    #test 2 - import polar from file
    polar2 = qprop.read_xfoil_polar_from_file("02_airfoil_polar_FX63-120_Re0.300_M0.00_N9.0.txt")
    if polar2.Re == 300000 \
                and abs(polar2.alpha[2] - qprop.deg2rad(2.000)) <= 1e-6 \
                and abs(polar2.CL[0] - 0.8022) <= 1e-6 \
                and abs(polar2.CD[polar2.size-1] - 0.06283) <= 1e-6 \
                and polar2.size == 14:
        print("TEST P2 - PASSED :)")
    else:
        print("TEST P2 - FAILED :(")
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
        print("TEST P3 - PASSED :)")
    else:
        print("TEST P3 - FAILED :(")
        qprop.free_polar(polar2)
        qprop.free_airfoil(naca4412)
        return

    #test 4 - read and refine propeller geometry
    apc10x7sf = qprop.import_rotor_geometry_apc(
        os.path.join("..","validation","apc_10x7sf","10x7SF-PERF.PE0"),
        naca4412
    )
    apc10x7sf_refined = qprop.refine_rotor_sections(apc10x7sf, 50)
    if apc10x7sf_refined.nsections == 50 \
                and apc10x7sf_refined.D == 10*0.0254 \
                and abs(apc10x7sf_refined.sections[apc10x7sf_refined.nsections-1].beta - qprop.deg2rad(12.5775)) <= 1e-6:
        print("TEST P4 - PASSED :)")
    else:
        print("TEST P4 - FAILED :(")
        qprop.free_polar(polar2)
        qprop.free_airfoil(naca4412)
        qprop.free_rotor(apc10x7sf)
        qprop.free_rotor(apc10x7sf_refined)
        return
    
    #test 5 - read propeller geometry from UIUC file
    apc10x7sf_uiuc = qprop.import_rotor_geometry_uiuc(
        os.path.join("..","validation","apc_10x7sf","uiuc_data","apcsf_10x7_geom.txt"),
        naca4412,
        10*0.0254,
        2
    )
    if (apc10x7sf_uiuc.nsections == 18 \
                and apc10x7sf_uiuc.D == 10*0.0254 \
                and abs(apc10x7sf_uiuc.sections[apc10x7sf_uiuc.nsections-1].beta - qprop.deg2rad(8.43)) <= 1e-6):
        print("TEST P5 - PASSED :)")
    else:
        print("TEST P5 - FAILED :(")
        qprop.free_polar(polar2)
        qprop.free_airfoil(naca4412)
        qprop.free_rotor(apc10x7sf)
        qprop.free_rotor(apc10x7sf_refined)
        qprop.free_rotor(apc10x7sf_uiuc)
        return

    #test 6 - analyze APC propeller at J=0.05
    Uinf = 1.2729633333333334      #freestream velocity (m/s)
    Omega = 629.7846072896339      #rotor speed (rad/s)
    result6 = qprop.qprop(apc10x7sf_refined, Uinf, Omega)
    if abs(result6.J - 0.05) <= 1e-6 \
                and abs(result6.T - 7.8) <= 0.1 \
                and abs(result6.Q - 0.14) <= 0.01:
        print("TEST P6 - PASSED :)")
    else:
        print("TEST P6 - FAILED :(")
        qprop.free_polar(polar2)
        qprop.free_airfoil(naca4412)
        qprop.free_rotor(apc10x7sf)
        qprop.free_rotor(apc10x7sf_refined)
        qprop.free_rotor(apc10x7sf_uiuc)
        qprop.free_rotor_performance(result6)
        return

    #completed
    qprop.free_polar(polar2)
    qprop.free_airfoil(naca4412)
    qprop.free_rotor(apc10x7sf)
    qprop.free_rotor(apc10x7sf_refined)
    qprop.free_rotor(apc10x7sf_uiuc)
    qprop.free_rotor_performance(result6)

if __name__ == "__main__":
    main()

