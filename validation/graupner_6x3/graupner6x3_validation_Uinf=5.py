#-------------------------------------------------------------------------------
#   Validation Script: Groupner 6x3 Propeller Aerodynamic Analysis
#
#   This script validates the accuracy of qprop.c by comparing its predictions
#   with values returned by the original QPROP (v1.22)
#   The present validation case uses the Groupner 6x3 propeller, the default
#   case proposed by QPROP.
#
#   How to run:
#   python3 graupner6x3_validation_Uinf=5.py
#
#   Author: Andrea Pavan
#   License: MIT
#-------------------------------------------------------------------------------
import ctypes;
import math;
import matplotlib.pyplot as plt;
import os;
import sys;
sys.path.insert(0, "./qprop/");
import qprop;

def main():
    #define airfoil polars using the analytical model of the original QPROP
    #the coefficients are matching those written in cam6x3.def
    airfoil_analytic = qprop.analytic_polar_curves(
        0.50, 5.8, -0.3, 1.2,           #CL0, CL_a, CLmin, CLmax
        0.028, 0.050, 0.020, 0.5,       #CD0, CD2u, CD2l, CLCD0
        70000.0, -0.7                   #REref, REexp
    )

    #read propeller geometry data from the original QPROP output
    original_output = []
    with open(os.path.join("original_qprop1.22_data_Uinf=5","cam6x3_qprop1.22_output.txt"), "r") as fileio:
        lines = fileio.readlines()[24:]     #skip the first 24 lines
        for line in lines:
            original_output.append([float(x) for x in line.split()])
    #the variable original_output is a List of List
    #original_output[i][1]: radial distance of the element centers (m)
    #original_output[i][2]: chord of each element (m)
    #original_output[i][3]: sweep angle of each element (deg)

    #create propeller geometry
    r = [row[0] for row in original_output]
    c = [row[1] for row in original_output]
    nelems = len(r)                     #number of elements
    dr = [0.0] * nelems                 #width of each element (m)
    dr[0] = r[1] - r[0]
    dr[1:-1] = [0.5 * (r[i+1] - r[i-1]) for i in range(1, nelems-1)]
    dr[-1] = r[-1] - r[-2]
    D = 2 * (r[-1] + 0.5 * dr[-1])      #propeller diameter (m) - should be 6inch=0.1524m
    B = 2                               #number of blades
    elements = []
    for i in range(nelems):
        newelement = qprop.create_element(
            c[i],
            qprop.deg2rad(original_output[i][2]),
            r[i],
            dr[i],
            airfoil_analytic
        )
        elements.append(newelement)
    graupner6x3 = qprop.create_rotor(D, B, nelems, elements)

    #run qprop.c
    Uinf = 5.0;                         #freestream velocity (m/s)
    Omega = 14020*math.pi/30;           #rotor speed (rad/s)
    qpropc_results = qprop.qprop(graupner6x3, Uinf, Omega, 1e-6, 200)
    for i in range(nelems):
        if abs(qpropc_results.residuals[i]) > 1e-6:
            print("ERROR while running qprop: convergence not reached in one or more elements")
            break
    print("qprop.c results:")
    print("  Thrust: ", round(qpropc_results.T, 5), " N")
    print("  Torque: ", round(qpropc_results.Q, 5), " N-m")

    #compare with original QPROP results
    Wa_original = [row[9] for row in original_output]
    Wt_original = [Wa * row[0] / (row[11] * (D/2))                  for Wa, row in zip(Wa_original, original_output)]
    W_original = [math.sqrt(Wa**2 + Wt**2)                          for Wa, Wt in zip(Wa_original, Wt_original)]
    phi_original = [math.atan(Wa/Wt)                                for Wa, Wt in zip(Wa_original, Wt_original)]
    Cl_original = [row[3] for row in original_output]
    Cd_original = [row[4] for row in original_output]
    Cn_original = [Cl * math.cos(phi) - Cd * math.sin(phi)          for Cl, Cd, phi in zip(Cl_original, Cd_original, phi_original)]
    Ct_original = [Cl * math.sin(phi) + Cd * math.cos(phi)          for Cl, Cd, phi in zip(Cl_original, Cd_original, phi_original)]
    dTdr_original = [0.5 * 1.225 * W**2 * Cn * row[1]               for W, Cn, row in zip(W_original, Cn_original, original_output)]
    dQdr_original = [0.5 * 1.225 * W**2 * Ct * row[1] * row[0]      for W, Ct, row in zip(W_original, Ct_original, original_output)]

    #compare thrust distributions
    plt1 = plt.figure(figsize=(6,4), dpi=100)       #600x400px
    plt.plot(
        [qpropc_results.r[i] / (D/2)        for i in range(nelems)],
        [qpropc_results.dTdr[i]             for i in range(nelems)],
        label = "qprop.c",
        linewidth = 2
    )
    plt.scatter(
        [r[i] / (D/2)                       for i in range(nelems)],
        dTdr_original,
        label = "QPROP v1.22",
        marker = "D",
        s = 20,
        color = "darkorange"
    )
    plt.title("Graupner 6x3 Thrust (Uinf=5.0m/s)")
    plt.xlabel("Blade radius r/R")
    plt.ylabel("Thrust distribution dT/dr (N/m)")
    plt.grid(True, which="both", linestyle="--", alpha=0.7)
    plt.legend()
    plt.tight_layout()
    plt.show()

    #compare torque distributions
    plt2 = plt.figure(figsize=(6,4), dpi=100)       #600x400px
    plt.plot(
        [qpropc_results.r[i] / (D/2)        for i in range(nelems)],
        [qpropc_results.dQdr[i]             for i in range(nelems)],
        label = "qprop.c",
        linewidth = 2
    )
    plt.scatter(
        [r[i] / (D/2)                       for i in range(nelems)],
        dQdr_original,
        label = "QPROP v1.22",
        marker = "D",
        s = 20,
        color = "darkorange"
    )
    plt.title("Graupner 6x3 Torque (Uinf=5.0m/s)")
    plt.xlabel("Blade radius r/R")
    plt.ylabel("Torque distribution dQ/dr (N-m/m)")
    plt.grid(True, which="both", linestyle="--", alpha=0.7)
    plt.legend()
    plt.tight_layout()
    plt.show()

if __name__ == "__main__":
    main()
