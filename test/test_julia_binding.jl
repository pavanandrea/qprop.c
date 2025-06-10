#-------------------------------------------------------------------------------
#   Testing script for the qprop.jl binding
#
#   How to run:
#   julia test_julia_binding.jl
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
        println("TEST J1 - PASSED :)");
    else
        println("TEST J1 - FAILED :(");
        return;
    end
    
    #test 2 - import polar from file
    polar2 = QProp.read_xfoil_polar_from_file(joinpath(@__DIR__,"02_airfoil_polar_FX63-120_Re0.300_M0.00_N9.0.txt"));
    if (polar2.Re == 300_000
                && abs(polar2.alpha[3] - QProp.deg2rad(2.000)) <= 1e-6
                && abs(polar2.CL[1] - 0.8022) <= 1e-6
                && abs(polar2.CD[polar2.size] - 0.06283) <= 1e-6
                && polar2.size == 14)
        println("TEST J2 - PASSED :)");
    else
        println("TEST J2 - FAILED :(");
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
        println("TEST J3 - PASSED :)");
    else
        println("TEST J3 - FAILED :(");
        return;
    end

    #test 4 - read and refine propeller geometry
    apc10x7sf = QProp.import_rotor_geometry_apc(
        joinpath(@__DIR__,"..","validation","apc_10x7sf","10x7SF-PERF.PE0"),
        naca4412
    );
    apc10x7sf_refined = QProp.refine_rotor_sections(apc10x7sf, 50);
    if (apc10x7sf_refined.nsections == 50
                && apc10x7sf_refined.D == 10*0.0254
                && abs(apc10x7sf_refined.sections[end].beta - QProp.deg2rad(12.5775)) <= 1e-6)
        println("TEST J4 - PASSED :)");
    else
        println("TEST J4 - FAILED :(");
        return;
    end

    #test 5 - read propeller geometry from UIUC file
    apc10x7sf_uiuc = QProp.import_rotor_geometry_uiuc(
        joinpath(@__DIR__,"..","validation","apc_10x7sf","uiuc_data","apcsf_10x7_geom.txt"),
        naca4412,
        10*0.0254,
        2
    );
    if (apc10x7sf_uiuc.nsections == 18
                && apc10x7sf_uiuc.D == 10*0.0254
                && abs(apc10x7sf_uiuc.sections[end].beta - QProp.deg2rad(8.43)) <= 1e-6)
        println("TEST J5 - PASSED :)");
    else
        println("TEST J5 - FAILED :(");
        return;
    end

    #test 6 - analyze APC propeller at J=0.05
    Uinf = 1.2729633333333334;      #freestream velocity (m/s)
    Omega = 629.7846072896339;      #rotor speed (rad/s)
    result6 = QProp.qprop(apc10x7sf_refined, Uinf, Omega);
    if (abs(result6.J - 0.05) <= 1e-6
                && abs(result6.T - 7.8) <= 0.1
                && abs(result6.Q - 0.14) <= 0.01)
        println("TEST J6 - PASSED :)");
    else
        println("TEST J6 - FAILED :(");
        return;
    end
end

main();
