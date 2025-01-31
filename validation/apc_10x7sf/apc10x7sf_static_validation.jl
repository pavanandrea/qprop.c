#-------------------------------------------------------------------------------
#   Validation Script: APC 10x7SF Propeller Aerodynamic Analysis
#
#   This script validates the accuracy of qprop.c by comparing its predictions
#   with experimental data from the UIUC wind tunnel.
#   The present validation case uses the APC 10x7SF propeller, a widely used
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
#   - Propeller: APC 10x7SF (10-inch diameter, 7-inch pitch)
#   - Airfoil: NACA-4412 (constant along the blade, for simplicity)
#   - Airfoil polars: generated using XFLR5 with NCrit=6
#
#   How to run:
#   julia apc10x7sf_static_validation.jl
#
#   Author: Andrea Pavan
#   License: MIT
#-------------------------------------------------------------------------------
using DelimitedFiles;
using Plots;
include("qprop/qprop.jl");
import .QProp;

function main()
    #read airfoil polars from files
    polar_filenames = [
        joinpath(@__DIR__, "airfoil_polar_naca4412_Ncrit=6", f)
        for f in readdir(joinpath(@__DIR__, "airfoil_polar_naca4412_Ncrit=6"))
        if endswith(f, ".txt")
    ];
    naca4412 = QProp.import_xfoil_polars(polar_filenames);

    #import propeller geometry from file
    apc10x7sf = QProp.import_rotor_geometry_apc(
        joinpath(@__DIR__,"10x7SF-PERF.PE0"),
        naca4412
    );
    
    #calculate propeller performance using qprop.c
    Uinf = 0.01;                        #freestream velocity (m/s)
    Ω = collect(2000:500:7000)*pi/30;   #vector containing rotor speeds (rad/s)
    CT0 = similar(Ω);                   #vector containing static thrust coefficients
    CP0 = similar(Ω);                   #vector containing static power coefficients
    for i=1:lastindex(Ω)
        #run analysis
        qprop_results = QProp.qprop(apc10x7sf, Uinf, Ω[i], 1e-8, 200, 1.225, 1.81e-5, 340.0);
        CT0[i] = qprop_results.CT;
        CP0[i] = qprop_results.CP;
    end

    #read UIUC experimental data from file
    (uiuc_data,_) = readdlm(
        joinpath(@__DIR__, "uiuc_data","apcsf_10x7_static_kt0827.txt"),     #filename
        Float64,                                                            #output format
        header = true                                                       #first line is an header
    );
    #the variable uiuc_data is a 16×3 Matrix{Float64}:
    # 2283.0  0.1409  0.0678
    # 2586.0  0.1424  0.0676
    # ⋮
    # 5987.0  0.1606  0.0797
    # (rpm)   (CT0)   (CP0)
    
    #plot RPM-CT
    #replicating https://m-selig.ae.illinois.edu/props/volume-1/plots/apcsf_10x7_static_ct.png
    plt1 = plot(Ω*30/pi, CT0, label="qprop.c", linewidth=2,
        title = "APC 10x7SF Thrust (Hovering)",
        legend = :bottomright,
        xlabel = "Rotor speed (rpm)",
        ylabel = "Static thrust coefficient CT",
        xlims = [1500, 7500],
        ylims = [0.00, 0.20],
        aspect_ratio = 1500/0.05,
        minorgrid = true,
        xticks = 1500:1500:7500,
        yticks = 0.00:0.05:0.20
    );
    scatter!(plt1, uiuc_data[:,1], uiuc_data[:,2], label="UIUC WT", markershape=:diamond, markersize=4);
    display(plt1);

    #plot RPM-CP
    #replicating https://m-selig.ae.illinois.edu/props/volume-1/plots/apcsf_10x7_static_cp.png
    plt2 = plot(Ω*30/pi, CP0, label="qprop.c", linewidth=2,
        title = "APC 10x7SF Power (Hovering)",
        legend = :bottomright,
        xlabel = "Rotor speed (rpm)",
        ylabel = "Static power coefficient CP",
        xlims = [1500, 7500],
        ylims = [0.00, 0.10],
        aspect_ratio = 1500/0.05,
        minorgrid = true,
        xticks = 1500:1500:7500,
        yticks = 0.00:0.05:0.10
    );
    scatter!(plt2, uiuc_data[:,1], uiuc_data[:,3], label="UIUC WT", markershape=:diamond, markersize=4);
    display(plt2);
end

main();
