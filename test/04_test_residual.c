/*******************************************************************************
    Testing program for the residual() function

    How to run:
    gcc 04_test_residual.c -o 04_test_residual -lm -Wall -Wextra
    ./04_test_residual

    Author: Andrea Pavan
    License: MIT
*******************************************************************************/
#include <math.h>
#include <stdio.h>
#include "../qprop.c"

int main() {
    //load NACA-4412 polars
    const char* filenames1[10] = {
        "./airfoil_polar_naca4412_Ncrit=6/NACA 4412_T1_Re0.030_M0.00_N6.0.txt",
        "./airfoil_polar_naca4412_Ncrit=6/NACA 4412_T1_Re0.040_M0.00_N6.0.txt",
        "./airfoil_polar_naca4412_Ncrit=6/NACA 4412_T1_Re0.060_M0.00_N6.0.txt",
        "./airfoil_polar_naca4412_Ncrit=6/NACA 4412_T1_Re0.080_M0.00_N6.0.txt",
        "./airfoil_polar_naca4412_Ncrit=6/NACA 4412_T1_Re0.100_M0.00_N6.0.txt",
        "./airfoil_polar_naca4412_Ncrit=6/NACA 4412_T1_Re0.130_M0.00_N6.0.txt",
        "./airfoil_polar_naca4412_Ncrit=6/NACA 4412_T1_Re0.160_M0.00_N6.0.txt",
        "./airfoil_polar_naca4412_Ncrit=6/NACA 4412_T1_Re0.200_M0.00_N6.0.txt",
        "./airfoil_polar_naca4412_Ncrit=6/NACA 4412_T1_Re0.300_M0.00_N6.0.txt",
        "./airfoil_polar_naca4412_Ncrit=6/NACA 4412_T1_Re0.500_M0.00_N6.0.txt"
    };
    Airfoil* naca4412 = import_xfoil_polars(filenames1, 10);

    //load propeller geometry from APC file
    Rotor* apc10x7sf = import_rotor_geometry_apc("../validation/apc_10x7sf/10x7SF-PERF.PE0", naca4412);
    double Uinf = 0.01;
    double Omega = 6014*M_PI/30;


    //test #1: blade geometry
    //printf("%i\n", apc10x7sf->nsections);
    //printf("%f\n", apc10x7sf->D);
    //printf("%f\n", apc10x7sf->sections[apc10x7sf->nsections-1].beta);
    if (apc10x7sf->nsections == 43
            && apc10x7sf->D == 0.254
            && fabs(apc10x7sf->sections[apc10x7sf->nsections-1].beta - deg2rad(12.5775)) <= 1e-6) {
        printf("TEST 4.1 - PASSED :)\n");
    }
    else {
        printf("TEST 4.1 - FAILED :(\n");
        free_rotor(apc10x7sf);
        free_airfoil(naca4412);
        return 0;
    }


    //test #2: residual function at the blade tip at psi=45°
    Element tipelement = {
        0.00226187,             //chord c (m)
        0.22008950933498891,    //pitch angle β (rad)
        0.12657709,             //radial position r (m)
        0.00084582,             //width dr (m)
        *naca4412               //airfoil polars
    };
    Residual residual2 = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0};
    residual(
        &residual2,
        deg2rad(+45.0),             //psi angle (rad)
        Uinf,
        Omega * tipelement.r,       //Ut=Omega*r (m/s)
        0.5 * apc10x7sf->D,
        apc10x7sf->B,
        &tipelement,
        1.225,
        1.81e-5,
        0.0
    );
    //printf("%f\n", residual2.residual);
    //printf("%f\n", residual2.W);
    //printf("%f\n", residual2.phi);
    if (fabs(residual2.residual) - 0.8024823651874253 <= 1e-6) {
        printf("TEST 4.2 - PASSED :)\n");
    }
    else {
        printf("TEST 4.2 - FAILED :(\n");
        free_rotor(apc10x7sf);
        free_airfoil(naca4412);
        return 0;
    }
    //Julia output:
    //  julia> qprop_residual(deg2rad(+45.0), 0.01, 6014*pi/30, 1.225, 1.81e-5, apc10x7sf, nelems)
    //      res = 0.8024823651874253,
    //      Cn = -0.35011489731684264,
    //      Ct = -0.007474065542410077,
    //      W = 73.65017452473688,
    //      Γ = 0.7753023257108531

    free_rotor(apc10x7sf);
    free_airfoil(naca4412);
    return 0;
}
