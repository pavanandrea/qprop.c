/*******************************************************************************
    Testing program for the fzero() function

    How to run:
    gcc 01_test_fzero.c -o 01_test_fzero -lm -Wall -Wextra
    ./01_test_fzero

    Author: Andrea Pavan
    License: MIT
*******************************************************************************/
#include <math.h>
#include <stdio.h>
#include "../src/qprop.c"

//define a function to find the root of
//this function has 5 roots: -2.7946409, -1.2061061, -0.5812517, 1.8449926, 2.7370304
double f1(double x) {
    return 0.5*pow(x,3) - 2*tan(0.5*x) - 0.5;
}

int main() {
    //test #1: find root of f1 in [-1,0]
    if (fabs(fzero(f1,-1.0,0.0,1e-6,100) + 0.5812517) < 1e-5) {
        printf("TEST 1.1 - PASSED :)\n");
    }
    else {
        printf("TEST 1.1 - FAILED :(\n");
    }
    
    return 0;
}
