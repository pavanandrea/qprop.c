#-------------------------------------------------------------------------------
#   Validation Script: APC 4.2x4 Propeller Aerodynamic Analysis
#
#   This script validates the accuracy of qprop.c by comparing its predictions
#   with experimental data from the UIUC wind tunnel.
#   The present validation case uses the APC 4.2x4 propeller, a widely used
#   and well-documented design.
#   The propeller geometry is imported from a PE0 file downloaded from the
#   manufacturer website.
#
#   This script simulates the propeller in hovering conditions at varying RPM.
#   It extracts the corresponding thrust and power coefficients and plots the
#   RPM-CT and RPM-CP curves. These curves are then compared with experimental
#   data to assess the accuracy of qprop.c at different Reynolds numbers.
#
#   Geometry and Assumptions:
#   - Propeller: APC 4.2x4 (4.2-inch diameter, 4-inch pitch)
#   - Airfoil: Clark-Y
#   - Airfoil polars: generated using XFLR5 with NCrit=7
#
#   How to run:
#   python3 apc42x4sf_static_validation.jl
#
#   Author: Andrea Pavan
#   License: MIT
#-------------------------------------------------------------------------------
import matplotlib.pyplot as plt;
import os;
import sys;
sys.path.insert(0, "./qprop/");
import qprop;

def main():
    #read airfoil polars from files
    polar_filenames = [
        os.path.join("airfoil_polar_clarky_Ncrit=7", f) \
        for f in os.listdir("airfoil_polar_clarky_Ncrit=7") \
        if f.endswith(".txt")
    ]
    clarky = qprop.import_xfoil_polars(polar_filenames)

    #import propeller geometry from file
    apc42x4 = qprop.import_rotor_geometry_apc("42x4-PERF.PE0", clarky)

    #calculate propeller performance using qprop.c
    Uinf = 0.01                                                     #freestream velocity (m/s)
    Omega = [i*3.14159265359/30 for i in range(1490, 9881, 500)]    #vector containing rotor speeds (rad/s)
    CT0 = [0] * len(Omega)                                          #vector containing static thrust coefficients
    CP0 = [0] * len(Omega)                                          #vector containing static power coefficients
    for i in range(len(Omega)):
        #run analysis
        qprop_results = qprop.qprop(apc42x4, Uinf, Omega[i], 1e-8, 200, 1.225, 1.81e-5, 340.0)
        CT0[i] = qprop_results.CT
        CP0[i] = qprop_results.CP

    #read UIUC experimental data from file
    uiuc_data = []
    with open(os.path.join("uiuc_data","apcff_4.2x4_static_0615rd.txt"), "r") as fileio:
        next(fileio)        #skip header
        for line in fileio:
            uiuc_data.append([float(x) for x in line.split()])
    #the variable uiuc_data is a List of List:
    #   [ [1490.0, 0.125114, 0.13544],
    #   [2033.333, 0.121907, 0.126335],
    #   ⋮
    #   [9880.0, 0.129241, 0.106961] ]
    #   (rpm)    (CT0)     (CP0)

    #plot RPM-CT
    #replicating https://m-selig.ae.illinois.edu/props/volume-2/plots/apcff_4.2x4_static_ctcp.png
    plt1 = plt.figure(figsize=(6,4), dpi=100)
    plt.plot([i*30/3.14159265359 for i in Omega], CT0, label="qprop.c", linewidth=2)
    plt.scatter([row[0] for row in uiuc_data], [row[1] for row in uiuc_data], label="UIUC WT", marker="D", s=20, color="darkorange")
    plt.title("APC 4.2x4 Thrust (Hovering)")
    plt.legend(loc="lower right")
    plt.xlabel("Rotor speed (rpm)")
    plt.ylabel("Static thrust coefficient CT")
    plt.xlim([0, 10000])
    plt.ylim([0.00, 0.15])
    plt.gca().set_aspect(2500 / 0.05)
    plt.grid(True, which="both")
    plt.xticks(range(0, 10001, 2500))
    plt.yticks([0.00, 0.05, 0.10, 0.15])
    plt.show()

    # Plot RPM-CP
    plt2 = plt.figure(figsize=(6,4), dpi=100)
    plt.plot([omega * 30 / 3.14159 for omega in Omega], CP0, label="qprop.c", linewidth=2)
    plt.scatter([row[0] for row in uiuc_data], [row[2] for row in uiuc_data], label="UIUC WT", marker="D", s=20, color="darkorange")
    plt.title("APC 4.2x4 Power (Hovering)")
    plt.legend(loc="lower right")
    plt.xlabel("Rotor speed (rpm)")
    plt.ylabel("Static power coefficient CP")
    plt.xlim([0, 10000])
    #plt.ylim([0.05, 0.15])
    plt.ylim([0.00, 0.15])
    plt.gca().set_aspect(2500 / 0.05)
    plt.grid(True, which="both")
    plt.xticks(range(0, 10001, 2500))
    #plt.yticks([0.05, 0.10, 0.15])
    plt.yticks([0.00, 0.05, 0.10, 0.15])
    plt.show()

if __name__ == "__main__":
    main();
