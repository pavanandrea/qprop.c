#-------------------------------------------------------------------------------
#   Validation Script: Groupner 6x3 Propeller Aerodynamic Analysis
#
#   This script validates the accuracy of qprop.c by comparing its predictions
#   with values returned by the original QPROP (v1.22)
#   The present validation case uses the Groupner 6x3 propeller, the default
#   case proposed by QPROP.
#
#   How to run:
#   julia graupner6x3_validation_hovering.jl
#
#   Author: Andrea Pavan
#   License: MIT
#-------------------------------------------------------------------------------
using DelimitedFiles;
using Plots;
include("qprop/qprop.jl");
import .QProp;

function main()
    #define airfoil polars using the analytical model of the original QPROP
    #the coefficients are matching those written in cam6x3.def
    airfoil_analytic = QProp.analytic_polar_curves(
        0.50, 5.8, -0.3, 1.2,           #CL0, CL_a, CLmin, CLmax
        0.028, 0.050, 0.020, 0.5,       #CD0, CD2u, CD2l, CLCD0
        70000.0, -0.7                   #REref, REexp
    );

    #read propeller geometry data from the original QPROP output
    original_output = readdlm(
        joinpath(@__DIR__, "original_qprop1.22_data_hovering", "cam6x3_qprop1.22_output.txt"),
        Float64,
        header = false,
        skipstart = 24
    );
    #the variable original_output is a 25×12 Matrix{Float64}:
    #original_output[:,1]: radial distance of the element centers (m)
    #original_output[:,2]: chord of each element (m)
    #original_output[:,3]: sweep angle of each element (deg)
    
    #create propeller geometry
    r = original_output[:,1];
    c = original_output[:,2];
    nelems = size(r, 1);                #number of elements
    dr = similar(r);                    #width of each element (m)
    dr[1] = r[2] - r[1];
    dr[2:end-1] = 0.5*(r[3:end] - r[1:end-2]);
    dr[end,1] = r[end] - r[end-1];
    D = 2*(r[end] + 0.5*dr[end]);       #propeller diameter (m) - should be 6inch=0.1524m
    B = 2;                              #number of blades
    elements = Vector{QProp.Element}(undef, nelems);
    for i=1:nelems
        elements[i] = QProp.Element(
            c[i],                               #Element.c (m)
            deg2rad(original_output[i,3]),      #Element.beta (rad)
            r[i],                               #Element.r (m)
            dr[i],                              #Element.dr (m)
            airfoil_analytic                    #Element.airfoil
        )
    end
    graupner6x3 = QProp.Rotor(D, B, nelems, elements);

    #run qprop.c
    Uinf = 0.01;                #freestream velocity (m/s)
    Ω = 14020*pi/30;            #rotor speed (rad/s)
    qpropc_results = QProp.qprop(graupner6x3, Uinf, Ω, 1e-6, 200);
    if any(abs.(qpropc_results.residuals) .> 1e-6)
        error("ERROR while running qprop: convergence not reached in one or more elements");
    end
    println("qprop.c results:");
    println("  Thrust: ", round(qpropc_results.T, digits=5), " N");
    println("  Torque: ", round(qpropc_results.Q, digits=5), " N-m");

    #compare with original QPROP results
    Wa_original = original_output[:,10];
    Wt_original = Wa_original .* r ./ (original_output[:,12] * (D/2));
    W_original = sqrt.(Wa_original.^2 + Wt_original.^2);
    phi_original = atan.(Wa_original./Wt_original);
    #vt_original = Wa_original .* tan.(deg2rad.(original_output[:,11]));
    Cl_original = original_output[:,4];
    Cd_original = original_output[:,5];
    Cn_original = Cl_original.*cos.(phi_original) - Cd_original.*sin.(phi_original);
    Ct_original = Cl_original.*sin.(phi_original) + Cd_original.*cos.(phi_original);
    dTdr_original = 0.5 * 1.225 * W_original.^2 .* Cn_original .* c;
    dQdr_original = 0.5 * 1.225 * W_original.^2 .* Ct_original .* c .* r;
    println("QPROP v1.22 results:");
    println("  Thrust: ", round(B*sum(dTdr_original.*dr), digits=5), " N");
    println("  Torque: ", round(B*sum(dQdr_original.*dr), digits=5), " N-m");

    #compare thrust distributions
    plt1 = plot(qpropc_results.r/(D/2), qpropc_results.dTdr, label="qprop.c", linewidth=2,
        title = "Graupner 6x3 Thrust (Hovering)",
        xlabel = "Blade radius r/R",
        ylabel = "Thrust distribution dT/dr (N/m)",
        minorgrid = true
    );
    scatter!(plt1, r/(D/2), dTdr_original, label="QPROP v1.22", markershape=:diamond, markersize=4);
    display(plt1);

    #compare torque distributions
    plt2 = plot(qpropc_results.r/(D/2), qpropc_results.dQdr, label="qprop.c", linewidth=2,
        title = "Graupner 6x3 Torque (Hovering)",
        xlabel = "Blade radius r/R",
        ylabel = "Torque distribution dQ/dr (N-m/m)",
        minorgrid = true
    );
    scatter!(plt2, r/(D/2), dQdr_original, label="QPROP v1.22", markershape=:diamond, markersize=4);
    display(plt2);
end

main();
