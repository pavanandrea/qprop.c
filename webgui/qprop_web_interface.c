/*******************************************************************************
    A wrapper of qprop.c to be accessed from JavaScript using WASM.

    Author: Andrea Pavan
    License: MIT
*******************************************************************************/
#include <math.h>
#include <stdio.h>
#include <emscripten/emscripten.h>
#include "../src/qprop.c"

Airfoil* available_airfoils[] = {NULL, NULL, NULL, NULL};
Rotor* rotor_geometry = NULL;

void initialize_geometry(double D, double B) {
    if (rotor_geometry) {
        free_rotor(rotor_geometry);
    }
    rotor_geometry = calloc(1, sizeof(Rotor));
    if (!rotor_geometry) {
        printf("ERROR: memory allocation error while initializing rotor_geometry\n");
        return;
    }
    rotor_geometry->D = D;
    rotor_geometry->B = B;
    rotor_geometry->nsections = 0;
    rotor_geometry->sections = NULL;
}

void add_geometry_section(double c, double beta, double r, int airfoil_idx) {
    if (airfoil_idx >= 4) {
        printf("ERROR while running add_section(): the provided airfoil_idx (%d) exceed the number of available airfoils\n", airfoil_idx);
        return;
    }
    push_rotor_section(rotor_geometry, c, beta, r, available_airfoils[airfoil_idx]);
    rotor_geometry->D = (2*r > rotor_geometry->D)? 2*r : rotor_geometry->D;
    //printf("Added section #%d (r=%fm)\n", rotor_geometry->nsections-1, rotor_geometry->sections[rotor_geometry->nsections-1].r);
}

void run_analysis(double Omega, double Uinf, double rho, double mu, int Npanels) {
    //create rotor
    if (!rotor_geometry || (rotor_geometry && rotor_geometry->nsections <= 0)) {
        printf("Invalid rotor geometry");
        return;
    }
    Rotor* rotor_refined = NULL;
    if (Npanels+1 > rotor_geometry->nsections) {
        rotor_refined = refine_rotor_sections(rotor_geometry, Npanels+1);
    }
    else {
        rotor_refined = rotor_geometry;
    }
    
    //run qprop
    EM_ASM({
        document.getElementById("results").innerHTML = `
            <p>Status: ` + Module.UTF8ToString($0) + `</p>
        `;
    }, "running...");
    double tol = 1e-6;
    RotorPerformance* perf = qprop(rotor_refined, Uinf, Omega, tol, 100, rho, mu, 340.0);
    
    //check convergence
    for (int i=0; i<perf->nelems; ++i) {
        if (perf->residuals[i] > tol) {
            EM_ASM({
                document.getElementById("results").innerHTML = `
                    <p>Status: ` + Module.UTF8ToString($0) + `</p>
                `;
            }, "unable to converge, please rerun the analysis");
            free_rotor_performance(perf);
            free_rotor(rotor_refined);
            return;
        }
    }

    //update values in results-container
    EM_ASM({
        document.getElementById("results").innerHTML = `
            <p>Status: ` + Module.UTF8ToString($0) + `</p>
            <p>Thrust: ` + $1.toFixed(4) + ` N (CT = ` + $2.toFixed(6) + `)</p>
            <p>Torque: ` + $3.toFixed(6) + ` N-m</p>
            <p>Power: ` + $4.toFixed(2) + ` W (CP = ` + $5.toFixed(6) + `)</p>
            <p>Advance Ratio J: ` + $6.toFixed(4) + `</p>
        `;
    }, "converged", perf->T, perf->CT, perf->Q, perf->Q*Omega, perf->CP, perf->J);
    free_rotor(rotor_refined);
    free_rotor_performance(perf);
    free_rotor(rotor_geometry);
}

int main() {
    printf("WASM Module qprop_web_interface running\n");
    initialize_geometry(0, 0);

    //load airfoil polars
    const char* naca4412_filenames[10] = {
        "./airfoil_polars/naca4412_Ncrit=6/NACA 4412_T1_Re0.030_M0.00_N6.0.txt",
        "./airfoil_polars/naca4412_Ncrit=6/NACA 4412_T1_Re0.040_M0.00_N6.0.txt",
        "./airfoil_polars/naca4412_Ncrit=6/NACA 4412_T1_Re0.060_M0.00_N6.0.txt",
        "./airfoil_polars/naca4412_Ncrit=6/NACA 4412_T1_Re0.080_M0.00_N6.0.txt",
        "./airfoil_polars/naca4412_Ncrit=6/NACA 4412_T1_Re0.100_M0.00_N6.0.txt",
        "./airfoil_polars/naca4412_Ncrit=6/NACA 4412_T1_Re0.130_M0.00_N6.0.txt",
        "./airfoil_polars/naca4412_Ncrit=6/NACA 4412_T1_Re0.160_M0.00_N6.0.txt",
        "./airfoil_polars/naca4412_Ncrit=6/NACA 4412_T1_Re0.200_M0.00_N6.0.txt",
        "./airfoil_polars/naca4412_Ncrit=6/NACA 4412_T1_Re0.300_M0.00_N6.0.txt",
        "./airfoil_polars/naca4412_Ncrit=6/NACA 4412_T1_Re0.500_M0.00_N6.0.txt"
    };
    available_airfoils[0] = import_xfoil_polars(naca4412_filenames, 10);
    const char* naca0012_filenames[10] = {
        "./airfoil_polars/naca0012_Ncrit=6/NACA 0012_T1_Re0.030_M0.00_N6.0.txt",
        "./airfoil_polars/naca0012_Ncrit=6/NACA 0012_T1_Re0.040_M0.00_N6.0.txt",
        "./airfoil_polars/naca0012_Ncrit=6/NACA 0012_T1_Re0.060_M0.00_N6.0.txt",
        "./airfoil_polars/naca0012_Ncrit=6/NACA 0012_T1_Re0.080_M0.00_N6.0.txt",
        "./airfoil_polars/naca0012_Ncrit=6/NACA 0012_T1_Re0.100_M0.00_N6.0.txt",
        "./airfoil_polars/naca0012_Ncrit=6/NACA 0012_T1_Re0.130_M0.00_N6.0.txt",
        "./airfoil_polars/naca0012_Ncrit=6/NACA 0012_T1_Re0.160_M0.00_N6.0.txt",
        "./airfoil_polars/naca0012_Ncrit=6/NACA 0012_T1_Re0.200_M0.00_N6.0.txt",
        "./airfoil_polars/naca0012_Ncrit=6/NACA 0012_T1_Re0.300_M0.00_N6.0.txt",
        "./airfoil_polars/naca0012_Ncrit=6/NACA 0012_T1_Re0.500_M0.00_N6.0.txt"
    };
    available_airfoils[1] = import_xfoil_polars(naca0012_filenames, 10);
    const char* eppler_e63_filenames[10] = {
        "./airfoil_polars/eppler_e63_Ncrit=6/E63_T1_Re0.030_M0.00_N6.0.txt",
        "./airfoil_polars/eppler_e63_Ncrit=6/E63_T1_Re0.040_M0.00_N6.0.txt",
        "./airfoil_polars/eppler_e63_Ncrit=6/E63_T1_Re0.060_M0.00_N6.0.txt",
        "./airfoil_polars/eppler_e63_Ncrit=6/E63_T1_Re0.080_M0.00_N6.0.txt",
        "./airfoil_polars/eppler_e63_Ncrit=6/E63_T1_Re0.100_M0.00_N6.0.txt",
        "./airfoil_polars/eppler_e63_Ncrit=6/E63_T1_Re0.130_M0.00_N6.0.txt",
        "./airfoil_polars/eppler_e63_Ncrit=6/E63_T1_Re0.160_M0.00_N6.0.txt",
        "./airfoil_polars/eppler_e63_Ncrit=6/E63_T1_Re0.200_M0.00_N6.0.txt",
        "./airfoil_polars/eppler_e63_Ncrit=6/E63_T1_Re0.300_M0.00_N6.0.txt",
        "./airfoil_polars/eppler_e63_Ncrit=6/E63_T1_Re0.500_M0.00_N6.0.txt"
    };
    available_airfoils[2] = import_xfoil_polars(eppler_e63_filenames, 10);
    const char* clark_y_filenames[10] = {
        "./airfoil_polars/clark_y_Ncrit=7/CLARK Y AIRFOIL_T1_Re0.030_M0.00_N7.0.txt",
        "./airfoil_polars/clark_y_Ncrit=7/CLARK Y AIRFOIL_T1_Re0.040_M0.00_N7.0.txt",
        "./airfoil_polars/clark_y_Ncrit=7/CLARK Y AIRFOIL_T1_Re0.060_M0.00_N7.0.txt",
        "./airfoil_polars/clark_y_Ncrit=7/CLARK Y AIRFOIL_T1_Re0.080_M0.00_N7.0.txt",
        "./airfoil_polars/clark_y_Ncrit=7/CLARK Y AIRFOIL_T1_Re0.100_M0.00_N7.0.txt",
        "./airfoil_polars/clark_y_Ncrit=7/CLARK Y AIRFOIL_T1_Re0.130_M0.00_N7.0.txt",
        "./airfoil_polars/clark_y_Ncrit=7/CLARK Y AIRFOIL_T1_Re0.160_M0.00_N7.0.txt",
        "./airfoil_polars/clark_y_Ncrit=7/CLARK Y AIRFOIL_T1_Re0.200_M0.00_N7.0.txt",
        "./airfoil_polars/clark_y_Ncrit=7/CLARK Y AIRFOIL_T1_Re0.300_M0.00_N7.0.txt",
        "./airfoil_polars/clark_y_Ncrit=7/CLARK Y AIRFOIL_T1_Re0.500_M0.00_N7.0.txt"
    };
    available_airfoils[3] = import_xfoil_polars(clark_y_filenames, 10);
    if (available_airfoils[0] && available_airfoils[1] && available_airfoils[2] && available_airfoils[3]) {
        printf("Airfoil polars loaded correctly\n");
        //printf("TEST - NACA4412 Re[0] CL[0] = %f\n", available_airfoils[0]->polars[0]->CL[0]);
    }
    return 0;
}

