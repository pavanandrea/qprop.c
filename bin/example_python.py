#-------------------------------------------------------------------------------
#   This script uses qprop.c to analyze the Groupner 6x3 propeller in hovering
#   conditions, based on the example provided in the QPROP User Manual
#   (https://web.mit.edu/drela/Public/web/qprop/)
#
#   How to run:
#   python3 example_python.py
#-------------------------------------------------------------------------------
import ctypes
import math
import sys
sys.path.insert(0, "./qprop/")
import qprop

def main():
    #----------------------------------------------------------
    #   define the airfoil characteristics of the propeller
    #----------------------------------------------------------

    #let's start by defining the airfoil characteristics of the propeller
    #the easiest way to do this is by using the analytical model of QPROP
    #the coefficients used below match those specified in the QPROP User Manual
    myairfoil = qprop.analytic_polar_curves(
        0.50, 5.8, -0.3, 1.2,           #CL0, CL_a, CLmin, CLmax
        0.028, 0.050, 0.020, 0.5,       #CD0, CD2u, CD2l, CLCD0
        70000.0, -0.7                   #REref, REexp
    )

    
    #ALTERNATIVE APPROACH: interpolate XFOIL/XFLR5 polars
    #if you prefer to use pre-computed polars from XFOIL or XFLR5, you can import them instead
    #to do this, specify a list of filenames in ascending order of the Reynolds number
    #for example:
    #filenames = ["path/to/my_airfoil_polar_Re0.050.txt", "path/to/my_airfoil_polar_Re0.100.txt"]
    #myairfoil = qprop.import_xfoil_polars(filenames)


    #----------------------------------------------------------
    #   define the geometry of the propeller
    #----------------------------------------------------------

    #let's continue by defining the geometry of the propeller
    #if you want to analyze an APC propeller, the easiest way is to read its geometry from a file.
    #for example, you can download a PE0 file from the APC website, then use the following function:
    #myrotor = qprop.import_rotor_geometry_apc("path/to/apc_geometry.PE0", myairfoil)


    #ALTERNATIVE APPROACH: define the propeller geometry manually
    #to do this, you need to specify the radius, chord and sweep angle of the propeller at various points along its span

    #the radius values should be in meters and should be specified in ascending order from the hub to the tip
    r = [0.0202, 0.0225, 0.0248, 0.0271, 0.0293, 0.0316, 0.0339, 0.0362, 0.0385, 0.0408, 0.0431, 0.0453, 0.0476, 0.0499, 0.0522, 0.0545, 0.0568, 0.0591, 0.0613, 0.0636, 0.0659, 0.0682, 0.0705, 0.0728, 0.0751]
    #note that the radius values will be used as the center points of each panel
    
    #the chord length values should also be in meters and should correspond to the radius values
    c = [0.0170, 0.0173, 0.0175, 0.0175, 0.0173, 0.0171, 0.0167, 0.0163, 0.0159, 0.0156, 0.0152, 0.0149, 0.0145, 0.0141, 0.0137, 0.0132, 0.0127, 0.0122, 0.0117, 0.0111, 0.0106, 0.0100, 0.0091, 0.0078, 0.0060]
    
    #the sweep angle values should be in radians and should correspond to the radius values
    β = [qprop.deg2rad(deg) for deg in [26.3800, 24.311, 22.471, 20.856, 19.442, 18.191, 17.065, 16.026, 15.037, 14.071, 13.130, 12.219, 11.344, 10.511, 9.7260, 8.9880, 8.2960, 7.6470, 7.0390, 6.4690, 5.9370, 5.4490, 5.0140, 4.6380, 4.3290]]
    
    #determine the number of panels discretizing each blade
    nelems = len(r)
    
    #now that the radius values at the center of each panel have been defined, the size (width) of each panel must be specified
    #this is done by calculating the difference in radius between adjacent panels
    dr = [0.0] * nelems
    dr[0] = r[1] - r[0]
    dr[1:-1] = [0.5 * (r[i+1] - r[i-1]) for i in range(1, nelems-1)]
    dr[-1] = r[-1] - r[-2]

    #calculate the propeller diameter (in meters)
    D = 2 * (r[-1] + 0.5 * dr[-1])      #should be equal to 6 inches = 0.1524 m

    #set the number of blades
    B = 2

    #finally, define the rotor elements and create the rotor object with the specified properties
    elements = []
    for i in range(nelems):
        newelement = qprop.create_element(
            c[i],           #Element.c (m)
            β[i],           #Element.beta (rad)
            r[i],           #Element.r (m)
            dr[i],          #Element.dr (m)
            myairfoil       #Element.airfoil
        )
        elements.append(newelement)
    myrotor = qprop.create_rotor(D, B, nelems, elements)


    #----------------------------------------------------------
    #   run analysis
    #----------------------------------------------------------

    #specify freestream velocity (in m/s) in axial direction
    Uinf = 0.00

    #specify rotor speed in rad/s
    #remember to multiply by pi/30 to convert from rpm to rad/s
    Ω = 14020*math.pi/30

    #run qprop.c
    results = qprop.qprop(myrotor, Uinf, Ω)
    for i in range(nelems):
        if abs(results.residuals[i]) > 1e-6:
            print("ERROR while running qprop: convergence not reached in one or more elements")
            break

    #print the results of the analysis
    print("qprop.c results:")
    print("  Thrust: ", round(results.T, 5), " N")
    print("  Torque: ", round(results.Q, 5), " N-m")
    #the expected output of the analysis is:
    #qprop.c results:
    #   Thrust: 3.22175 N
    #   Torque: 0.02969 N-m

if __name__ == "__main__":
    main()
