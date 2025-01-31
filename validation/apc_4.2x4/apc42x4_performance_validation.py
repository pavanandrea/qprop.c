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
#   This script simulates the propeller in cruise conditions at varying Uinf.
#   It extracts the corresponding thrust and power coefficients and plots the
#   J-CT and J-CP curves. These curves are then compared with experimental
#   data to assess the accuracy of qprop.c at replicating an entire propeller
#   operating diagram.
#
#   Geometry and Assumptions:
#   - Propeller: APC 4.2x4 (4.2-inch diameter, 4-inch pitch)
#   - Airfoil: Clark-Y
#   - Airfoil polars: generated using XFLR5 with NCrit=7
#
#   How to run:
#   python3 apc42x4_performance_validation.jl
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
    Uinf = [0.5+0.5*i for i in range(35)]       #vector containing freestream velocities (m/s) - 0.5:0.5:10.5
    Omega = 10042*3.14159265359/30              #rotor speed (rad/s)
    CT = [0] * len(Uinf)                        #vector containing thrust coefficients
    CP = [0] * len(Uinf)                        #vector containing power coefficients
    eta = [0] * len(Uinf)                       #vector containing propeller efficiencies
    J = [0] * len(Uinf)                         #vector containing advance ratios
    for i in range(len(Uinf)):
        #run analysis
        qprop_results = qprop.qprop(apc42x4, Uinf[i], Omega, 1e-8, 200, 1.225, 1.81e-5, 340.0)
        CT[i] = qprop_results.CT
        CP[i] = qprop_results.CP
        J[i] = qprop_results.J
        eta[i] = J[i] * CT[i] / CP[i]

    #read UIUC experimental data by concatenating two files
    uiuc_data = []
    with open(os.path.join("uiuc_data","apcff_4.2x4_0620rd_10042.txt"), "r") as fileio:
        next(fileio)                #skip header
        for line in fileio:
            uiuc_data.append([float(x) for x in line.split()])
    with open(os.path.join("uiuc_data","apcff_4.2x4_0621rd_10071.txt"), "r") as fileio:
        next(fileio)                #skip header
        for line in fileio:
            uiuc_data.append([float(x) for x in line.split()])
    uiuc_data = uiuc_data[:-3]      #skip points with negative thrust
    #the variable uiuc_data is a List of List:
    #   [ [0.113578  0.128215  0.112438  0.129516],
    #     [0.170594  0.126315  0.112042  0.192328],
    #     ⋮
    #     [0.962425  0.011545  0.035425  0.313629] ]
    #     (J)       (CT)       (CP)     (eta)

    #plot J-CT
    #replicating https://m-selig.ae.illinois.edu/props/volume-2/plots/apcff_4.2x4_ct.png
    plt1 = plt.figure(figsize=(6,4), dpi=100)
    plt.plot(J, CT, label="qprop.c", linewidth=2)
    plt.scatter([row[0] for row in uiuc_data], [row[1] for row in uiuc_data], label="UIUC WT", marker="D", s=20, color="darkorange")
    plt.title("APC 4.2x4 Thrust ({} rpm)".format(int(Omega*30/3.14159265359)))
    plt.legend(loc="upper right")
    plt.xlabel("Advance ratio J")
    plt.ylabel("Thrust coefficient CT")
    plt.xlim([0.0, 1.2])
    plt.ylim([0.00, 0.15])
    plt.gca().set_aspect(0.2 / 0.05)
    plt.grid(True, which="both")
    plt.xticks([0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 1.2])
    plt.yticks([0.00, 0.05, 0.10, 0.15])
    plt.show()

    #plot J-CP
    #replicating https://m-selig.ae.illinois.edu/props/volume-2/plots/apcff_4.2x4_cp.png
    plt1 = plt.figure(figsize=(6,4), dpi=100)
    plt.plot(J, CP, label="qprop.c", linewidth=2)
    plt.scatter([row[0] for row in uiuc_data], [row[2] for row in uiuc_data], label="UIUC WT", marker="D", s=20, color="darkorange")
    plt.title("APC 4.2x4 Power ({} rpm)".format(int(Omega*30/3.14159265359)))
    plt.legend(loc="upper right")
    plt.xlabel("Advance ratio J")
    plt.ylabel("Power coefficient CP")
    plt.xlim([0.0, 1.2])
    plt.ylim([0.00, 0.15])
    plt.gca().set_aspect(0.2 / 0.05)
    plt.grid(True, which="both")
    plt.xticks([0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 1.2])
    plt.yticks([0.00, 0.05, 0.10, 0.15])
    plt.show()

    #plot J-eta
    #replicating https://m-selig.ae.illinois.edu/props/volume-2/plots/apcff_4.2x4_eta.png
    plt1 = plt.figure(figsize=(6,4), dpi=100)
    plt.plot(J, eta, label="qprop.c", linewidth=2)
    plt.scatter([row[0] for row in uiuc_data], [row[3] for row in uiuc_data], label="UIUC WT", marker="D", s=20, color="darkorange")
    plt.title("APC 4.2x4 Efficiency ({} rpm)".format(int(Omega*30/3.14159265359)))
    plt.legend(loc="upper right")
    plt.xlabel("Advance ratio J")
    plt.ylabel("Efficiency η")
    plt.xlim([0.0, 1.2])
    plt.ylim([0.0, 0.8])
    plt.gca().set_aspect(0.2 / 0.2)
    plt.grid(True, which="both")
    plt.xticks([0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 1.2])
    plt.yticks([0.0, 0.2, 0.4, 0.6, 0.8])
    plt.show()

if __name__ == "__main__":
    main();
