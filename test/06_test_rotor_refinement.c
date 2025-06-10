/*******************************************************************************
    Testing program for the refine_rotor_sections() function

    How to run:
    gcc 06_test_rotor_refinement.c -o 06_test_rotor_refinement -lm -Wall -Wextra
    ./06_test_rotor_refinement

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

    //load propeller geometry from UIUC txt file
    Rotor* apc10x7sf = import_rotor_geometry_uiuc("../validation/apc_10x7sf/uiuc_data/apcsf_10x7_geom.txt", naca4412, 10*0.0254, 2);
    /*printf("%8s  -  %8s  -  %8s\n", "r", "c", "beta");
    for (int i=0; i<apc10x7sf->nsections; ++i) {
        printf("%.6f  -  %.6f  -  %.6f\n", apc10x7sf->sections[i].r, apc10x7sf->sections[i].c, apc10x7sf->sections[i].beta);
    }*/

    //test #1: blade geometry
    if (apc10x7sf->nsections == 18
            && apc10x7sf->D == 10*0.0254
            && fabs(apc10x7sf->sections[apc10x7sf->nsections-1].beta - deg2rad(8.43)) <= 1e-6) {
        printf("TEST 6.1 - PASSED :)\n");
    }
    else {
        printf("TEST 6.1 - FAILED :(\n");
        free_rotor(apc10x7sf);
        free_airfoil(naca4412);
        return 0;
    }

    //test #2: refined blade with more sections
    Rotor* rotor2 = refine_rotor_sections(apc10x7sf, 36);
    //printf("%i\n", rotor2->nsections);
    //printf("%f\n", rotor2->D);
    //printf("%f\n", rotor2->sections[rotor2->nsections-1].beta);
    /*printf("%8s  -  %8s  -  %8s\n", "r", "c", "beta");
    for (int i=0; i<rotor2->nsections; ++i) {
        printf("%.6f  -  %.6f  -  %.6f\n", rotor2->sections[i].r, rotor2->sections[i].c, rotor2->sections[i].beta);
    }*/
    if (rotor2->nsections == 36
            && rotor2->D == 10*0.0254
            && fabs(rotor2->sections[rotor2->nsections-1].beta - deg2rad(8.43)) <= 1e-6) {
        printf("TEST 6.2 - PASSED :)\n");
    }
    else {
        printf("TEST 6.2 - FAILED :(\n");
        free_rotor(apc10x7sf);
        free_rotor(rotor2);
        free_airfoil(naca4412);
        return 0;
    }

    //test #3: coarsened blade with less sections
    Rotor* rotor3 = refine_rotor_sections(apc10x7sf, 9);
    /*printf("%8s  -  %8s  -  %8s\n", "r", "c", "beta");
    for (int i=0; i<rotor3->nsections; ++i) {
        printf("%.6f  -  %.6f  -  %.6f\n", rotor3->sections[i].r, rotor3->sections[i].c, rotor3->sections[i].beta);
    }*/
    if (rotor3->nsections == 9
            && rotor3->D == 10*0.0254
            && fabs(rotor3->sections[rotor3->nsections-1].beta - deg2rad(8.43)) <= 1e-6) {
        printf("TEST 6.3 - PASSED :)\n");
    }
    else {
        printf("TEST 6.3 - FAILED :(\n");
        free_rotor(apc10x7sf);
        free_rotor(rotor2);
        free_rotor(rotor3);
        free_airfoil(naca4412);
        return 0;
    }

    //test #4: compare performance with the three discretizations
    double Uinf = 1.2729633333333334;
    double Omega = 6014*M_PI/30;
    double tol = 1e-6;
    int itmax = 100;
    double rho = 1.225;
    double mu = 1.81e-5;
    double a = 0.0;
    RotorPerformance* perf1 = qprop(apc10x7sf, Uinf, Omega, tol, itmax, rho, mu, a);
    RotorPerformance* perf2 = qprop(rotor2, Uinf, Omega, tol, itmax, rho, mu, a);
    RotorPerformance* perf3 = qprop(rotor3, Uinf, Omega, tol, itmax, rho, mu, a);
    //printf("Thrust (09 panels): %f N\n", perf3->T);
    //printf("Thrust (18 panels): %f N\n", perf1->T);
    //printf("Thrust (36 panels): %f N\n", perf2->T);
    if (fabs(perf1->T - 6.7) <= 0.1
            && fabs(perf2->T - 6.7) <= 0.1
            && fabs(perf3->T - 6.7) <= 0.1) {
        printf("TEST 6.4 - PASSED :)\n");
    }
    else {
        printf("TEST 6.4 - FAILED :(\n");
        free_rotor(apc10x7sf);
        free_rotor(rotor2);
        free_rotor(rotor3);
        free_airfoil(naca4412);
        free_rotor_performance(perf1);
        free_rotor_performance(perf2);
        free_rotor_performance(perf3);
        return 0;
    }

    free_rotor(apc10x7sf);
    free_rotor(rotor2);
    free_rotor(rotor3);
    free_airfoil(naca4412);
    return 0;
}
