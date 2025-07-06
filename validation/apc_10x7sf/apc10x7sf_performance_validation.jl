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
#   This script simulates the propeller in cruise conditions at varying Uinf
#   and several speeds Ω.
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
    #Uinf = collect(0.5:0.5:20.0);              #vector of freestream velocities (m/s)
    Jdesired = collect(0.05:0.01:0.80);         #vector of desired advanced ratios
    Ω = [3000.0, 4000.0, 5000.0, 6000.0] * pi/30;       #vector of rotor speeds (rad/s)
    CT = zeros(length(Jdesired),length(Ω));     #matrix of thrust coefficients
    CP = zeros(length(Jdesired),length(Ω));     #matrix of power coefficients
    η = zeros(length(Jdesired),length(Ω));      #matrix of propeller efficiencies
    J = zeros(length(Jdesired),length(Ω));      #matrix of advance ratios
    for i in 1:lastindex(Jdesired)
        for j in 1:lastindex(Ω)
            #run analysis
            Uinf = Jdesired[i] * (Ω[j]/(2*pi)) * apc10x7sf.D;
            qprop_results = QProp.qprop(apc10x7sf, Uinf, Ω[j], 1e-8, 200, 1.225, 1.81e-5, 340.0);
            CT[i,j] = qprop_results.CT;
            CP[i,j] = qprop_results.CP;
            J[i,j] = qprop_results.J;
            η[i,j] = J[i,j] * CT[i,j] / CP[i,j];
        end
    end

    #read UIUC experimental data
    #files with the same speed are concatenated
    (uiuc_data_3000,_) = readdlm(
        joinpath(@__DIR__,"uiuc_data","apcsf_10x7_kt0828_3008.txt"),
        Float64,
        header = true
    );
    (uiuc_data_4000_file1,_) = readdlm(
        joinpath(@__DIR__,"uiuc_data","apcsf_10x7_kt0829_4011.txt"),
        Float64,
        header = true
    );
    (uiuc_data_4000_file2,_) = readdlm(
        joinpath(@__DIR__,"uiuc_data","apcsf_10x7_kt0830_3999.txt"),
        Float64,
        header = true
    );
    uiuc_data_4000 = vcat(uiuc_data_4000_file1, uiuc_data_4000_file2[1:7,:]);       #skip points with negative thrust
    (uiuc_data_5000_file1,_) = readdlm(
        joinpath(@__DIR__,"uiuc_data","apcsf_10x7_kt0831_5003.txt"),
        Float64,
        header = true
    );
    (uiuc_data_5000_file2,_) = readdlm(
        joinpath(@__DIR__,"uiuc_data","apcsf_10x7_kt0832_5006.txt"),
        Float64,
        header = true
    );
    uiuc_data_5000 = vcat(uiuc_data_5000_file1, uiuc_data_5000_file2[1:13,:]);      #skip points with negative thrust
    (uiuc_data_6000_file1,_) = readdlm(
        joinpath(@__DIR__,"uiuc_data","apcsf_10x7_kt0833_6006.txt"),
        Float64,
        header = true
    );
    (uiuc_data_6000_file2,_) = readdlm(
        joinpath(@__DIR__,"uiuc_data","apcsf_10x7_kt0834_6014.txt"),
        Float64,
        header = true
    );
    uiuc_data_6000 = vcat(uiuc_data_6000_file1, uiuc_data_6000_file2[1:20,:]);      #skip points with negative thrust
    #the variable uiuc_data is a 37x4 Matrix{Float64}:
    # 0.092  0.1559  0.0805  0.178
    # 0.120  0.1527  0.0803  0.228
    # ⋮
    # 0.857  0.0048  0.0239  0.172
    # (J)    (CT)    (CP)    (η)
    
    #plot J-CT
    #replicating https://m-selig.ae.illinois.edu/props/volume-1/plots/apcsf_10x7_ct.png
    plt1 = plot(J[:,1], CT[:,1], label=false, linewidth=2, color=RGB(100/255, 143/255, 255/255),
        title = "APC 10x7SF Thrust",
        legend = :topright,
        xlabel = "Advance ratio J",
        ylabel = "Thrust coefficient CT",
        xlims = [0.0, 0.8],
        ylims = [0.00, 0.17],
        aspect_ratio = 0.17/0.05,
        minorgrid = true,
        xticks = 0.0:0.2:0.8,
        yticks = 0.00:0.05:0.17
    );
    plot!(plt1, J[:,2], CT[:,2], label=false, linewidth=2, color=RGB(120/255, 94/255, 240/255));
    #plot!(plt1, J[:,3], CT[:,3], label=false, linewidth=2);
    plot!(plt1, J[:,4], CT[:,4], label="qprop.c", linewidth=2, color=RGB(220/255, 38/255, 127/255));
    scatter!(plt1, uiuc_data_3000[:,1], uiuc_data_3000[:,2], label=false, markersize=4, markershape=:circle, color=RGB(100/255, 143/255, 255/255));
    scatter!(plt1, uiuc_data_4000[:,1], uiuc_data_4000[:,2], label=false, markersize=4, markershape=:rect, color=RGB(120/255, 94/255, 240/255));
    #scatter!(plt1, uiuc_data_5000[:,1], uiuc_data_5000[:,2], label=false, markersize=4);
    scatter!(plt1, uiuc_data_6000[:,1], uiuc_data_6000[:,2], label="UIUC WT", markersize=4, markershape=:diamond, color=RGB(220/255, 38/255, 127/255));
    display(plt1);

    #plot J-CP
    #replicating https://m-selig.ae.illinois.edu/props/volume-1/plots/apcsf_10x4.7_cp.png
    plt2 = plot(J[:,1], CP[:,1], label=false, linewidth=2, color=RGB(100/255, 143/255, 255/255),
        title = "APC 10x7SF Power",
        legend = :bottomleft,
        xlabel = "Advance ratio J",
        ylabel = "Power coefficient CP",
        xlims = [0.0, 0.8],
        ylims = [0.00, 0.10],
        aspect_ratio = 0.20/0.10,
        minorgrid = true,
        xticks = 0.0:0.2:0.8,
        yticks = 0.00:0.05:0.10
    );
    plot!(plt2, J[:,2], CP[:,2], label=false, linewidth=2, color=RGB(120/255, 94/255, 240/255));
    #plot!(plt2, J[:,3], CP[:,3], label=false, linewidth=2);
    plot!(plt2, J[:,4], CP[:,4], label="qprop.c", linewidth=2, color=RGB(220/255, 38/255, 127/255));
    scatter!(plt2, uiuc_data_3000[:,1], uiuc_data_3000[:,3], label=false, markersize=4, markershape=:circle, color=RGB(100/255, 143/255, 255/255));
    scatter!(plt2, uiuc_data_4000[:,1], uiuc_data_4000[:,3], label=false, markersize=4, markershape=:rect, color=RGB(120/255, 94/255, 240/255));
    #scatter!(plt2, uiuc_data_5000[:,1], uiuc_data_5000[:,3], label=false, markersize=4);
    scatter!(plt2, uiuc_data_6000[:,1], uiuc_data_6000[:,3], label="UIUC WT", markersize=4, markershape=:diamond, color=RGB(220/255, 38/255, 127/255));
    display(plt2);

    #plot J-η
    #replicating https://m-selig.ae.illinois.edu/props/volume-1/plots/apcsf_10x7_eta.png
    plt3 = plot(J[:,1], η[:,1], label=false, linewidth=2, color=RGB(100/255, 143/255, 255/255),
        title = "APC 10x7SF Efficiency",
        legend = :topleft,
        xlabel = "Advance ratio J",
        ylabel = "Efficiency η",
        xlims = [0.0, 0.8],
        ylims = [0.2, 0.8],
        aspect_ratio = 1.0,
        minorgrid = true,
        xticks = 0.0:0.2:0.8,
        yticks = 0.2:0.2:0.8
    );
    plot!(plt3, J[:,2], η[:,2], label=false, linewidth=2, color=RGB(120/255, 94/255, 240/255));
    #plot!(plt3, J[:,3], η[:,3], label=false, linewidth=2);
    plot!(plt3, J[:,4], η[:,4], label="qprop.c", linewidth=2, color=RGB(220/255, 38/255, 127/255));
    scatter!(plt3, uiuc_data_3000[:,1], uiuc_data_3000[:,4], label=false, markersize=4, markershape=:circle, color=RGB(100/255, 143/255, 255/255));
    scatter!(plt3, uiuc_data_4000[:,1], uiuc_data_4000[:,4], label=false, markersize=4, markershape=:rect, color=RGB(120/255, 94/255, 240/255));
    #scatter!(plt3, uiuc_data_5000[:,1], uiuc_data_5000[:,4], label=false, markersize=4);
    scatter!(plt3, uiuc_data_6000[:,1], uiuc_data_6000[:,4], label="UIUC WT", markersize=4, markershape=:diamond, color=RGB(220/255, 38/255, 127/255));
    display(plt3);
end

main();
