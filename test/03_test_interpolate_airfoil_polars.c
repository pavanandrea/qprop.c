/*******************************************************************************
    Testing program for the interpolate_airfoil_polars() function

    How to run:
    gcc 03_test_interpolate_airfoil_polars.c -o 03_test_interpolate_airfoil_polars -lm -Wall -Wextra
    ./03_test_interpolate_airfoil_polars

    Author: Andrea Pavan
    License: MIT
*******************************************************************************/
#include <math.h>
#include <stdio.h>
#include "../qprop.c"

int main() {
    //load NACA-4412 polars
    const char* filenames1[4] = {
        "./airfoil_polar_naca4412_Ncrit=6/NACA 4412_T1_Re0.030_M0.00_N6.0.txt",
        "./airfoil_polar_naca4412_Ncrit=6/NACA 4412_T1_Re0.100_M0.00_N6.0.txt",
        "./airfoil_polar_naca4412_Ncrit=6/NACA 4412_T1_Re0.200_M0.00_N6.0.txt",
        "./airfoil_polar_naca4412_Ncrit=6/NACA 4412_T1_Re0.500_M0.00_N6.0.txt"
    };
    Airfoil* airfoil1 = import_xfoil_polars(filenames1, 4);

    //print 100k polar
    /*printf("%8s  -  %8s  -  %8s\n", "alpha", "CL", "CD");
    for (int i=0; i<airfoil1->polars[1].size; ++i) {
        printf("%.6f  -  %.6f  -  %.6f\n", airfoil1->polars[1].alpha[i], airfoil1->polars[1].CL[i], airfoil1->polars[1].CD[i]);
    }
    printf("Size = %i\n", airfoil1->polars[1].size);*/

    //test #1: interpolate on the 100k polar
    PolarPoint* polarpoint1 = interpolate_polar(&airfoil1->polars[1], deg2rad(4.25));
    if (fabs(polarpoint1->CL - 0.9074) <= 1e-6 && fabs(polarpoint1->CD - 0.017235) <= 1e-6) {
        printf("TEST 3.1 - PASSED :)\n");
    }
    else {
        printf("TEST 3.1 - FAILED :(\n");
        free_airfoil(airfoil1);
        return 0;
    }

    //test #2: retrieve alphamin point on the 30k polar
    PolarPoint* polarpoint2 = interpolate_polar(&airfoil1->polars[0], deg2rad(-15.0));
    if (fabs(polarpoint2->CL + 0.4209) <= 1e-6 && fabs(polarpoint2->CD - 0.18542) <= 1e-6) {
        printf("TEST 3.2 - PASSED :)\n");
    }
    else {
        printf("TEST 3.2 - FAILED :(\n");
        free_airfoil(airfoil1);
        return 0;
    }

    //test #3: interpolate above CLmax
    PolarPoint* polarpoint3 = interpolate_polar(&airfoil1->polars[3], deg2rad(+90.0));
    if (fabs(polarpoint3->CL - 1.5299) <= 1e-6 && fabs(polarpoint3->CD - 2.0) <= 1e-6) {
        printf("TEST 3.3 - PASSED :)\n");
    }
    else {
        printf("TEST 3.3 - FAILED :(\n");
        free_airfoil(airfoil1);
        return 0;
    }

    //test #4: interpolate in between polars
    PolarPoint* polarpoint4 = interpolate_airfoil_polars(airfoil1, deg2rad(+4.5), 150000, 0.0);
    if (fabs(polarpoint4->CL - 0.93785) <= 1e-6 && fabs(polarpoint4->CD - 0.015125) <= 1e-6) {
        printf("TEST 3.4 - PASSED :)\n");
    }
    else {
        printf("TEST 3.4 - FAILED :(\n");
        free_airfoil(airfoil1);
        return 0;
    }

    //test #5: interpolate above highest polar
    PolarPoint* polarpoint5 = interpolate_airfoil_polars(airfoil1, deg2rad(+15.0), 1000000, 0.0);
    if (fabs(polarpoint5->CL - 1.5299) <= 1e-6 && fabs(polarpoint5->CD - 0.05227) <= 1e-6) {
        printf("TEST 3.5 - PASSED :)\n");
    }
    else {
        printf("TEST 3.5 - FAILED :(\n");
        free_airfoil(airfoil1);
        return 0;
    }

    free_airfoil(airfoil1);
    return 0;
}
