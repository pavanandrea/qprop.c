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
#   This script simulates the propeller in cruise conditions at varying Uinf.
#   It extracts the corresponding thrust and power coefficients and plots the
#   J-CT and J-CP curves. These curves are then compared with experimental
#   data to assess the accuracy of qprop.c at replicating an entire propeller
#   operating diagram.
#
#   Geometry and Assumptions:
#   - Propeller: APC 10x7SF (10-inch diameter, 7-inch pitch)
#   - Airfoil: NACA-4412 (constant along the blade, for simplicity)
#   - Airfoil polars: generated using XFLR5 with NCrit=6
#
#   How to run:
#   julia apc10x7sf_performance_validation.jl
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
    Uinf = collect(0.5:0.5:20.0);   #vector containing freestream velocities (m/s)
    Ω = 6014*pi/30;                 #rotor speed (rad/s)
    CT = similar(Uinf);             #vector containing thrust coefficients
    CP = similar(Uinf);             #vector containing power coefficients
    η = similar(Uinf);              #vector containing propeller efficiencies
    J = similar(Uinf);              #vector containing advance ratios
    for i=1:lastindex(Uinf)
        #run analysis
        qprop_results = QProp.qprop(apc10x7sf, Uinf[i], Ω, 1e-8, 200, 1.225, 1.81e-5, 340.0);
        CT[i] = qprop_results.CT;
        CP[i] = qprop_results.CP;
        J[i] = qprop_results.J;
        η[i] = J[i] * CT[i] / CP[i];
    end

    #read UIUC experimental data by concatenating two files
    (uiuc_data_file1,_) = readdlm(
        joinpath(@__DIR__,"uiuc_data","apcsf_10x7_kt0833_6006.txt"),
        Float64,
        header = true
    );
    (uiuc_data_file2,_) = readdlm(
        joinpath(@__DIR__,"uiuc_data","apcsf_10x7_kt0834_6014.txt"),
        Float64,
        header = true
    );
    uiuc_data = vcat(uiuc_data_file1, uiuc_data_file2[1:20,:]);     #skip points with negative thrust
    #the variable uiuc_data is a 37x4 Matrix{Float64}:
    # 0.092  0.1559  0.0805  0.178
    # 0.120  0.1527  0.0803  0.228
    # ⋮
    # 0.857  0.0048  0.0239  0.172
    # (J)    (CT)    (CP)    (η)
    
    #plot J-CT
    #replicating https://m-selig.ae.illinois.edu/props/volume-1/plots/apcsf_10x7_ct.png
    plt1 = plot(J, CT, label="qprop.c", linewidth=2,
        title = "APC 10x7SF Thrust ("*string(Int(Ω*30/pi))*" rpm)",
        legend = :topright,
        xlabel = "Advance ratio J",
        ylabel = "Thrust coefficient CT",
        xlims = [0.0, 1.0],
        ylims = [0.00, 0.20],
        aspect_ratio = 0.20/0.05,
        minorgrid = true,
        xticks = 0.0:0.2:1.0,
        yticks = 0.00:0.05:0.20
    );
    scatter!(plt1, uiuc_data[:,1], uiuc_data[:,2], label="UIUC WT", markershape=:diamond, markersize=4);
    display(plt1);

    #plot J-CP
    #replicating https://m-selig.ae.illinois.edu/props/volume-1/plots/apcsf_10x4.7_cp.png
    plt2 = plot(J, CP, label="qprop.c", linewidth=2,
        title = "APC 10x7SF Power ("*string(Int(Ω*30/pi))*" rpm)",
        legend = :topright,
        xlabel = "Advance ratio J",
        ylabel = "Power coefficient CP",
        xlims = [0.0, 1.0],
        ylims = [0.00, 0.10],
        aspect_ratio = 0.20/0.05,
        minorgrid = true,
        xticks = 0.0:0.2:1.0,
        yticks = 0.00:0.05:0.10
    );
    scatter!(plt2, uiuc_data[:,1], uiuc_data[:,3], label="UIUC WT", markershape=:diamond, markersize=4);
    display(plt2);

    #plot J-η
    #replicating https://m-selig.ae.illinois.edu/props/volume-1/plots/apcsf_10x7_eta.png
    plt3 = plot(J, η, label="qprop.c", linewidth=2,
        title = "APC 10x7SF Efficiency ("*string(Int(Ω*30/pi))*" rpm)",
        legend = :topright,
        xlabel = "Advance ratio J",
        ylabel = "Efficiency η",
        xlims = [0.0, 1.0],
        ylims = [0.0, 1.0],
        aspect_ratio = 1.0,
        minorgrid = true,
        xticks = 0.0:0.2:1.0,
        yticks = 0.0:0.2:1.0
    );
    scatter!(plt3, uiuc_data[:,1], uiuc_data[:,4], label="UIUC WT", markershape=:diamond, markersize=4);
    display(plt3);
end

main();
