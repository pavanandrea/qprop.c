#-------------------------------------------------------------------------------
#   This script uses qprop.c to analyze the Graupner 6x3 propeller in hovering
#   conditions, based on the example provided in the QPROP User Manual
#   (https://web.mit.edu/drela/Public/web/qprop/)
#
#   How to run:
#   python3 example_python.py
#-------------------------------------------------------------------------------
import math
import sys
sys.path.insert(0, "./qprop-portable/")
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

    #OR, if you want to import a propeller geometry from the UIUC database:
    #myrotor = qprop.import_rotor_geometry_uiuc("path/to/propeller_geometry.txt", myairfoil, propeller_diameter, number_of_blades)
    #                                                                                        ⬑e.g: 0.2           ⬑e.g: 2

    #ALTERNATIVE APPROACH: define the propeller geometry manually
    #to do this, you need to specify the radius, chord and sweep angle of the propeller at various points along its span

    #the radius values should be in meters and should be specified in ascending order from the hub to the tip
    r = [0.01905, 0.0254, 0.0381, 0.0508, 0.0635, 0.073025, 0.0762]
    #    ⬑hub                                               ⬑tip
    
    #the chord length values should also be in meters and should correspond to the radius values
    c = [0.016764, 0.017526, 0.016002, 0.01397, 0.011176, 0.00762, 0.004826]
    #    ⬑hub                                                      ⬑tip

    #the sweep angle values should be in radians and should correspond to the radius values
    β = [qprop.deg2rad(deg) for deg in [27.5, 22.0, 15.2, 10.2, 6.5, 4.6, 4.2]]
    
    #extract the number of sections, to make subsequent calculations more convenient
    nsections = len(r)
    
    #calculate the propeller diameter (in meters)
    D = 2 * r[-1]       #should be equal to 6 inches = 0.1524 m

    #specify the number of blades
    B = 2

    #finally, define the rotor elements and create the rotor object with the specified properties
    sections = []
    for i in range(nsections):
        newsection = qprop.create_section(
            c[i],           #Element.c (m)
            β[i],           #Element.beta (rad)
            r[i],           #Element.r (m)
            myairfoil       #Element.airfoil
        )
        sections.append(newsection)
    myrotor = qprop.create_rotor(D, B, nsections, sections)


    #----------------------------------------------------------
    #   run analysis
    #----------------------------------------------------------

    #specify freestream velocity (in m/s) in axial direction
    Uinf = 0.00

    #specify rotor speed in rad/s
    #remember to multiply by pi/30 to convert from rpm to rad/s
    Ω = 14020 * math.pi/30

    #run qprop.c
    results = qprop.qprop(myrotor, Uinf, Ω)
    for i in range(nsections):
        if abs(results.residuals[i]) > 1e-6:
            print("ERROR while running qprop: convergence not reached in one or more elements")
            break

    #print the results of the analysis
    print("qprop.c results:")
    print("  Thrust: ", round(results.T, 5), " N")
    print("  Torque: ", round(results.Q, 5), " N-m")
    #the expected output of the analysis is:
    #qprop.c results:
    #   Thrust: 3.26103 N
    #   Torque: 0.03005 N-m

if __name__ == "__main__":
    main()
