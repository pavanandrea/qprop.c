#-------------------------------------------------------------------------------
#   Testing script for the qprop.jl binding
#
#   How to run:
#   julia 06b_test_julia_binding.jl
#
#   Author: Andrea Pavan
#   License: MIT
#-------------------------------------------------------------------------------
include("../build/qprop-portable/qprop.jl");
import .QProp;

function main()
    #test 1 - simple utilities
    myangle = QProp.deg2rad(+45.0);
    if abs(myangle - 0.7853981633974483) <= 1e-6
        println("TEST 1 - PASSED :)");
    else
        println("TEST 1 - FAILED :(");
        return;
    end
    
    #test 2 - import polar from file
    polar2 = QProp.read_xfoil_polar_from_file(joinpath(@__DIR__,"02_airfoil_polar_FX63-120_Re0.300_M0.00_N9.0.txt"));
    if (polar2.Re == 300_000
                && abs(polar2.alpha[3] - QProp.deg2rad(2.000)) <= 1e-6
                && abs(polar2.CL[1] - 0.8022) <= 1e-6
                && abs(polar2.CD[polar2.size] - 0.06283) <= 1e-6
                && polar2.size == 14)
        println("TEST 2 - PASSED :)");
    else
        println("TEST 2 - FAILED :(");
        return;
    end

    #test 3 - import airfoil from files
    filenames3 = [
        joinpath(@__DIR__, "airfoil_polar_naca4412_Ncrit=6", f)
        for f in readdir(joinpath(@__DIR__, "airfoil_polar_naca4412_Ncrit=6"))
        if endswith(f, ".txt")
    ];
    naca4412 = QProp.import_xfoil_polars(filenames3);
    if naca4412.size == 10 && naca4412.polars[1].alpha[1] == QProp.deg2rad(-15.0)
        println("TEST 3 - PASSED :)");
    else
        println("TEST 3 - FAILED :(");
        return;
    end

    #test 4 - analyze APC propeller at J=0.05
    apc10x7sf = QProp.import_rotor_geometry_apc(
        joinpath(@__DIR__,"..","validation","apc_10x7sf","10x7SF-PERF.PE0"),
        naca4412
    );
    Uinf = 1.2729633333333334;      #freestream velocity (m/s)
    Omega = 629.7846072896339;      #rotor speed (rad/s)
    result4 = QProp.qprop(apc10x7sf, Uinf, Omega);
    if (abs(result4.J - 0.05) <= 1e-6
                && abs(result4.T - 7.811303879404407) <= 1e-6
                && abs(result4.Q - 0.14308075154669447) <= 1e-6)
        println("TEST 4 - PASSED :)");
    else
        println("TEST 4 - FAILED :(");
        return;
    end
end

main();
