/*******************************************************************************
    Testing program for the qprop() function

    How to run:
    gcc 05_test_qprop.c -o 05_test_qprop -lm -Wall -Wextra
    ./05_test_qprop

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
    Airfoil naca4412 = import_xfoil_polars(filenames1, 10);

    //load propeller geometry from APC file
    Rotor apc10x7sf = import_rotor_geometry_apc("../validation/apc_10x7sf/10x7SF-PERF.PE0", &naca4412);
    double Omega = 6014*M_PI/30;
    double tol = 1e-6;
    int itmax = 100;
    double rho = 1.225;
    double mu = 1.81e-5;
    double a = 0.0;

    //test #1: J = 0.05
    //printf("TEST 1\n");
    double Uinf = 1.2729633333333334;
    RotorPerformance perf1 = qprop(&apc10x7sf, Uinf, Omega, tol, itmax, rho, mu, a);
    //printf("    Uinf: %f\n", Uinf);
    //printf("    Thrust: %f\n", perf1.T);
    //printf("    Torque: %f\n", perf1.Q);
    if (fabs(perf1.T - 7.811303879404407) <= 1e-6 && fabs(perf1.Q - 0.14308075154669447) <= 1e-6) {
        printf("TEST 1 - PASSED :)\n");
    }
    else {
        printf("TEST 1 - FAILED :(\n");
        unload_rotor_from_memory(&apc10x7sf);
        unload_airfoil_from_memory(&naca4412);
        unload_rotor_performance_from_memory(&perf1);
        return 0;
    }
    //Julia results:
    //Uinf = 1.272963333333334 m/s  -  Thrust = 7.811303879404407 N  -  Torque = 0.14308075154669447 N-m
    //Element 1  -  psi = 0.49888845469758536 rad
    //Element 1  -  W = 13.68266147170133 m/s
    //Element 1  -  Cn = 0.8830965959757509
    //Element 1  -  Ct = 0.555597268677166
    //Element 42  -  psi = 0.16914190573461374 rad
    //Element 42  -  W = 79.49275796892873 m/s
    //Element 42  -  Cn = 0.8382696556496837
    //Element 42  -  Ct = 0.14739650613749866


    //test #2: J = 0.75
    //printf("TEST 2\n");
    Uinf = 19.09445;
    RotorPerformance perf2 = qprop(&apc10x7sf, Uinf, Omega, tol, itmax, rho, mu, a);
    //printf("  Uinf: %f\n", Uinf);
    //printf("  Thrust: %f\n", perf2.T);
    //printf("  Torque: %f\n", perf2.Q);
    if (fabs(perf2.T - 1.1348963862887862) <= 1e-6 && fabs(perf2.Q - 0.05252953779296362) <= 1e-6) {
        printf("TEST 2 - PASSED :)\n");
    }
    else {
        printf("TEST 2 - FAILED :(\n");
        unload_rotor_from_memory(&apc10x7sf);
        unload_airfoil_from_memory(&naca4412);
        unload_rotor_performance_from_memory(&perf1);
        unload_rotor_performance_from_memory(&perf2);
        return 0;
    }
    /*
    //Julia results:
    Uinf = 1.2729633333333334 m/s  -  Thrust = 7.811303879404407 N  -  Torque = 0.14308075154669447 N-m
    Uinf = 2.545926666666667 m/s  -  Thrust = 7.5809187450271835 N  -  Torque = 0.14524469873222853 N-m
    Uinf = 3.81889 m/s  -  Thrust = 7.32061016853633 N  -  Torque = 0.14681290420213122 N-m
    Uinf = 5.091853333333334 m/s  -  Thrust = 7.02562891997085 N  -  Torque = 0.1477194182109727 N-m
    Uinf = 6.364816666666667 m/s  -  Thrust = 6.6646208983089545 N  -  Torque = 0.14733995874807745 N-m
    Uinf = 7.63778 m/s  -  Thrust = 6.245346524572363 N  -  Torque = 0.14523447152924293 N-m
    Uinf = 8.910743333333333 m/s  -  Thrust = 5.797827666347191 N  -  Torque = 0.1417658418125231 N-m
    Uinf = 10.183706666666668 m/s  -  Thrust = 5.321703109325795 N  -  Torque = 0.13687424390996958 N-m
    Uinf = 11.45667 m/s  -  Thrust = 4.813713635410416 N  -  Torque = 0.13036405148150873 N-m
    Uinf = 12.729633333333334 m/s  -  Thrust = 4.279056143723284 N  -  Torque = 0.122229083381802 N-m
    Uinf = 14.002596666666667 m/s  -  Thrust = 3.7151404055268156 N  -  Torque = 0.11227835761023904 N-m
    Uinf = 15.27556 m/s  -  Thrust = 3.1285953514663483 N  -  Torque = 0.10054394413268984 N-m
    Uinf = 16.548523333333335 m/s  -  Thrust = 2.472376199831624 N  -  Torque = 0.08568417842799038 N-m
    Uinf = 17.821486666666665 m/s  -  Thrust = 1.7951408123607697 N  -  Torque = 0.06960429493382134 N-m
    Uinf = 19.09445 m/s  -  Thrust = 1.1348963862887862 N  -  Torque = 0.05252953779296362 N-m
    */

    unload_rotor_from_memory(&apc10x7sf);
    unload_airfoil_from_memory(&naca4412);
    unload_rotor_performance_from_memory(&perf1);
    unload_rotor_performance_from_memory(&perf2);
    return 0;
}
