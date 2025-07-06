#-------------------------------------------------------------------------------
#   This script uses qprop.c to analyze the Graupner 6x3 propeller in hovering
#   conditions, based on the example provided in the QPROP User Manual
#   (https://web.mit.edu/drela/Public/web/qprop/)
#
#   How to run:
#   julia example_julia.jl
#-------------------------------------------------------------------------------
using DelimitedFiles;
using Plots;
include("qprop-portable/qprop.jl");
import .QProp;

function main()
    #----------------------------------------------------------
    #   define the airfoil characteristics of the propeller
    #----------------------------------------------------------

    #let's start by defining the airfoil characteristics of the propeller
    #the easiest way to do this is by using the analytical model of QPROP
    #the coefficients used below match those specified in the QPROP User Manual
    myairfoil = QProp.analytic_polar_curves(
        0.50, 5.8, -0.3, 1.2,           #CL0, CL_a, CLmin, CLmax
        0.028, 0.050, 0.020, 0.5,       #CD0, CD2u, CD2l, CLCD0
        70000.0, -0.7                   #REref, REexp
    );

    
    #ALTERNATIVE APPROACH: interpolate XFOIL/XFLR5 polars
    #if you prefer to use pre-computed polars from XFOIL or XFLR5, you can import them instead
    #to do this, specify a list of filenames in ascending order of the Reynolds number
    #for example:
    #filenames = ["path/to/my_airfoil_polar_Re0.050.txt", "path/to/my_airfoil_polar_Re0.100.txt"];
    #myairfoil = QProp.import_xfoil_polars(filenames);


    #----------------------------------------------------------
    #   define the geometry of the propeller
    #----------------------------------------------------------

    #let's continue by defining the geometry of the propeller
    #if you want to analyze an APC propeller, the easiest way is to read its geometry from a file.
    #for example, you can download a PE0 file from the APC website, then use the following function:
    #myrotor = QProp.import_rotor_geometry_apc("path/to/apc_geometry.PE0", myairfoil);

    #OR, if you want to import a propeller geometry from the UIUC database:
    #myrotor = QProp.import_rotor_geometry_uiuc("path/to/propeller_geometry.txt", myairfoil, propeller_diameter, number_of_blades)
    #                                                                                        ⬑e.g: 0.2           ⬑e.g: 2

    #ALTERNATIVE APPROACH: define the propeller geometry manually
    #to do this, you need to specify the radius, chord and sweep angle of the propeller at various sections along its span

    #the radius values should be in meters and should be specified in ascending order from the hub to the tip
    r = [0.75, 1.00, 1.50, 2.00, 2.50, 2.875, 3.00] * 0.0254;
    #    ⬑hub                                ⬑tip    ⬑convert inches to meters
    
    #the chord length values should also be in meters and should correspond to the radius values
    c = [0.66, 0.69, 0.63, 0.55, 0.44, 0.30, 0.19] * 0.0254;
    #    ⬑hub                                ⬑tip   ⬑convert inches to meters
    
    #the sweep angle values should be in radians and should correspond to the radius values
    β = deg2rad.([27.5, 22.0, 15.2, 10.2, 6.5, 4.6, 4.2]);
    
    #extract the number of sections, to make subsequent calculations more convenient
    nsections = size(r, 1);
    
    #calculate the propeller diameter (in meters)
    D = 2*r[end];       #should be equal to 6 inches = 0.1524 m

    #specify the number of blades
    B = 2;

    #finally, define the rotor elements and create the rotor object with the specified properties
    sections = Vector{QProp.Section}(undef, nsections);
    for i=1:nsections
        sections[i] = QProp.Section(
            c[i],           #Element.c (m)
            β[i],           #Element.β (rad)
            r[i],           #Element.r (m)
            myairfoil       #Element.airfoil
        )
    end
    myrotor = QProp.Rotor(D, B, nsections, sections);


    #----------------------------------------------------------
    #   run analysis
    #----------------------------------------------------------

    #specify freestream velocity (in m/s) in axial direction
    Uinf = 0.00;

    #specify rotor speed in rad/s
    #remember to multiply by pi/30 to convert from rpm to rad/s
    Ω = 14020 * pi/30;

    #run qprop.c
    results = QProp.qprop(myrotor, Uinf, Ω);
    if any(abs.(results.residuals) .> 1e-6)
        error("ERROR while running qprop.c: convergence not reached in one or more elements");
    end

    #print the results of the analysis
    println("qprop.c results:");
    println("  Thrust: ", round(results.T, digits=5), " N");
    println("  Torque: ", round(results.Q, digits=5), " N-m");
    #the expected output of the analysis is:
    #qprop.c results:
    #   Thrust: 3.26103 N
    #   Torque: 0.03005 N-m
end

main();
