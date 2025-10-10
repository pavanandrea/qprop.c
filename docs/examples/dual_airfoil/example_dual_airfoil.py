#-------------------------------------------------------------------------------
#   This script demonstrates how to run qprop.c on a single rotor that uses
#   two different airfoils along its span:
#   - Eppler E63 from the hub (r = 0) out to 80% of the radius (r/R ≤ 0.8)
#   - NACA‑4412 from 80% of the radius to the tip (r/R > 0.8)
#
#   IMPORTANT: the results are **not** validated!
#
#   Run with:
#   python3 example_dual_airfoil.py
# -------------------------------------------------------------------------------
import math
import os
import sys
sys.path.insert(0, "./qprop-portable/")
import qprop

def main():
    #define airfoil #1: Eppler E63
    airfoil1_polar_filenames = [
        os.path.join("./eppler_e63_Ncrit=6", filename) \
        for filename in os.listdir("eppler_e63_Ncrit=6") \
        if filename.endswith(".txt")
    ]
    airfoil1 = qprop.import_xfoil_polars(airfoil1_polar_filenames)

    #define airfoil #2: NACA 4412
    airfoil2_polar_filenames = [
        os.path.join("./naca4412_Ncrit=6", filename) \
        for filename in os.listdir("naca4412_Ncrit=6") \
        if filename.endswith(".txt")
    ]
    airfoil2 = qprop.import_xfoil_polars(airfoil2_polar_filenames)

    #define propeller geometry
    r = [0.01905, 0.0254, 0.0381, 0.0508, 0.0635, 0.073025, 0.0762]                 #radial stations (m)
    c = [0.016764, 0.017526, 0.016002, 0.01397, 0.011176, 0.00762, 0.004826]        #chord (m)
    β = [qprop.deg2rad(deg) for deg in [27.5, 22.0, 15.2, 10.2, 6.5, 4.6, 4.2]]     #blade pitch angle (rad)

    #define rotor sections
    D = 2 * r[-1]                   #rotor diameter (m)
    B = 2                           #number of blades
    nsections = len(r)              #number of blade sections
    sections = []
    for i in range(nsections):
        if r[i] <= 0.8 * r[-1]:
            #use Eppler E63 for r <= 0.8*R
            newsection = qprop.create_section(
                c[i],               #Element.c (m)
                β[i],               #Element.beta (rad)
                r[i],               #Element.r (m)
                airfoil1            #Element.airfoil
            )
            sections.append(newsection)
        else:
            #use NACA-4412 for r > 0.8*R
            newsection = qprop.create_section(
                c[i],               #Element.c (m)
                β[i],               #Element.beta (rad)
                r[i],               #Element.r (m)
                airfoil2            #Element.airfoil
            )
            sections.append(newsection)

    myrotor = qprop.create_rotor(D, B, nsections, sections)

    #run analysis
    Uinf = 0.00                     #airspeed (m/s)
    Ω = 14020 * math.pi/30          #rotor speed (rad/s)
    results = qprop.qprop(myrotor, Uinf, Ω)

    #check convergence
    for i in range(nsections):
        if abs(results.residuals[i]) > 1e-6:
            print("ERROR while running qprop: convergence not reached in one or more elements")
            break

    #print results
    print("qprop.c results:")
    print("  Thrust: ", round(results.T, 5), " N")
    print("  Torque: ", round(results.Q, 5), " N-m")

if __name__ == "__main__":
    main()
