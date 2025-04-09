/*******************************************************************************
    qprop.c: a simple and lightweight library for propeller aerodynamic analysis

    It uses the same mathematical formulation as Mark Drela's QPROP, which makes
    it well-suited for rotors that operate at low Reynolds numbers and do not
    feature complex 3D effects.

    Key characteristics:
    - Lightweight and portable: contained in a single file with no dependencies
    - No file I/O required: perform analyses and retrieve results without
      writing input files or reading output files
    - Easy to use: simply copy the library into your project directory
    - Accurate airfoil polars: unlike the original QPROP, which requires users
      to tune oversimplified analytic models, qprop.c gets the aerodynamic
      coefficients of the airfoils by interpolating XFoil polars

    How to compile using Zig:
    zig cc qprop.c -o qprop-lib-windows-x64.dll -target x86_64-windows-gnu -shared -lm -fPIC -O2 -Wall -Wextra
    zig cc qprop.c -o qprop-lib-linux-x64.so -target x86_64-linux-gnu -shared -lm -fPIC -O2 -Wall -Wextra
    zig cc qprop.c -o qprop-lib-macos-arm64.dylib -target aarch64-macos -shared -lm -fPIC -O2 -Wall -Wextra

    Author: Andrea Pavan
    License: MIT
*******************************************************************************/
#include <ctype.h>
#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "qprop.h"

#define MAX_LINE_LENGTH 256     //maximum length of a line in a xfoil polar file



//---------------------------
//  FUNCTION DEFINITIONS
//---------------------------


//converts degrees to radians
double deg2rad(double deg) {
    return deg*M_PI/180.0;
}

//read xfoil polar from file
//WARNING: the content of the file is not checked
//the polar is supposed to start at min(alpha), go to 0 and finish at max(alpha)
Polar* read_xfoil_polar_from_file(const char *filename) {
    Polar* newpolar = malloc(sizeof(Polar));
    if (!newpolar) {
        printf("ERROR: memory allocation error in read_xfoil_polar_from_file()\n");
        return NULL;
    }
    newpolar->Re = 0.0;
    newpolar->alpha = NULL;
    newpolar->CL = NULL;
    newpolar->CD = NULL;
    newpolar->size = 0;

    FILE* fileio = fopen(filename, "rb");
    if (!fileio) {
        printf("ERROR opening file %s\n", filename);
        free(newpolar);
        return NULL;
    }

    //read file line by line
    char line[MAX_LINE_LENGTH];
    bool read_reynolds_number = true;
    bool read_polar_points = false;
    while (fgets(line, MAX_LINE_LENGTH, fileio)) {
        //read Reynolds number
        if (read_reynolds_number && strstr(line, "Re =")) {     //if line contains "Re ="
            //line now is looking like this:
            //line = " Mach =   0.000     Re =     0.300 e 6     Ncrit =   9.000";
            char* token = strtok(line, " ");                    //split line into tokens
            while (token) {
                //printf("Token: %s\n", token);
                if (strcmp(token, "Re") == 0) {
                    //found the "Re" token
                    token = strtok(NULL, " ");                  //get the next token "="
                    token = strtok(NULL, " ");                  //get the next token "0.300"
                    double mantissa = atof(token);
                    double exponent = 0.0;
                    token = strtok(NULL, " ");                  //get the next token "e"
                    if (strcmp(token, "e") == 0) {
                        token = strtok(NULL, " ");              //get the next token "6"
                        exponent = atof(token);
                    }
                    newpolar->Re = mantissa*pow(10,exponent);
                    break;
                }
                token = strtok(NULL, " ");                      //get the next token
            }
            read_reynolds_number = false;
        }

        //read polar points
        if (read_polar_points && !strstr(line, "---")) {
            //line now is looking like this:
            //line = "   0.000   0.8022   0.01019   0.00422  -0.1836   0.7434   0.5993";
            //printf("line = \"%s\"\n",line);
            char* token = strtok(line, " ");                    //split line into tokens
            if (!token || strlen(token)<=2) {
                //empty line
                break;
            }

            //add an element to alpha, CL, CD
            newpolar->alpha = (double*) realloc(newpolar->alpha, (newpolar->size+1)*sizeof(double));
            newpolar->CL = (double*) realloc(newpolar->CL, (newpolar->size+1)*sizeof(double));
            newpolar->CD = (double*) realloc(newpolar->CD, (newpolar->size+1)*sizeof(double));
            newpolar->size += 1;

            //set the last element of alpha, CL, CD
            newpolar->alpha[newpolar->size-1] = deg2rad(atof(token));
            token = strtok(NULL, " ");                          //get the next token "0.8022"
            newpolar->CL[newpolar->size-1] = atof(token);
            token = strtok(NULL, " ");                          //get the next token "0.01019"
            newpolar->CD[newpolar->size-1] = atof(token);
        }

        //check if line contains "alpha", "CL", "CD" to eventually start reading polar points
        if (!read_reynolds_number && !read_polar_points && strstr(line, "alpha") && strstr(line, "CL") && strstr(line, "CD")) {
            //starting reading polar points from the line following the next one
            read_polar_points = true;
        }
    }
    fclose(fileio);
    if (newpolar->Re==0 || newpolar->size==0) {
        printf("ERROR unable to parse polar from %s\n", filename);
        free(newpolar->alpha);
        free(newpolar->CL);
        free(newpolar->CD);
        free(newpolar);
        return NULL;
    }
    return newpolar;
}

//free allocated memory on a polar
void free_polar(Polar *currentpolar) {
    if (currentpolar->alpha) {
        free(currentpolar->alpha);
    }
    if (currentpolar->CL) {
        free(currentpolar->CL);
    }
    if (currentpolar->CD) {
        free(currentpolar->CD);
    }
    free(currentpolar);
}

//free allocated memory on an airfoil
void free_airfoil(Airfoil *currentairfoil) {
    for (int i=0; i<currentairfoil->size; ++i) {
        free(currentairfoil->polars[i].alpha);
        free(currentairfoil->polars[i].CL);
        free(currentairfoil->polars[i].CD);
    }
    free(currentairfoil->polars);
    free(currentairfoil);
}

//import xfoil polars from multiple files
//WARNING: safety checks on user input are not implemented yet
//WARNING: the content of each file is not checked
Airfoil* import_xfoil_polars(const char *filenames[], int number_of_files) {
    Airfoil* newairfoil = malloc(sizeof(Airfoil));
    if (!newairfoil) {
        printf("ERROR: memory allocation error in import_xfoil_polars()\n");
        return NULL;
    }
    newairfoil->polars = (Polar*) malloc(number_of_files*sizeof(Polar));
    newairfoil->size = number_of_files;
    if (!newairfoil->polars) {
        printf("ERROR: memory allocation error in import_xfoil_polars()\n");
        free(newairfoil);
        return NULL;
    }
    for (int i=0; i<number_of_files; ++i) {
        newairfoil->polars[i] = *read_xfoil_polar_from_file(filenames[i]);
    }
    return newairfoil;
}

//generate polars using the simple analytic model described by Drela in the QPROP user guide
Airfoil* analytic_polar_curves(double CL0, double CL_a, double CLmin, double CLmax,
                              double CD0, double CD2u, double CD2l, double CLCD0,
                              double REref, double REexp) {
    Airfoil* newairfoil = malloc(sizeof(Airfoil));
    if (!newairfoil) {
        printf("ERROR: memory allocation error in analytic_polar_curves()\n");
        return NULL;
    }

    //pre-define ranges for Re and alpha
    const double Re[] = {30000.0, 50000.0, 75000.0, 100000.0, 150000.0, 200000.0, 500000.0};
    const double alpha[] = {-45.0, -30.0, -20.0, -15.0, -12.0, -10.0, -9.0, -8.0,
                            -7.0, -6.0, -5.0, -4.0, -3.0, -2.0, -1.0, 0.0, +1.0,
                            +2.0, +3.0, +4.0, +5.0, +6.0, +7.0, +8.0, +9.0, +10.0,
                            +12.0, +15.0, +20.0, +30.0, +45.0};
    const int size_Re = sizeof(Re) / sizeof(Re[0]);
    const int size_alpha = sizeof(alpha) / sizeof(alpha[0]);
    
    //define "analytic airfoil"
    //Airfoil newairfoil;
    newairfoil->polars = (Polar*) malloc(size_Re*sizeof(Polar));
    newairfoil->size = size_Re;
    for (int i=0; i<size_Re; ++i) {
        newairfoil->polars[i].Re = Re[i];
        newairfoil->polars[i].alpha = (double*) malloc(size_alpha*sizeof(double));
        newairfoil->polars[i].CL = (double*) malloc(size_alpha*sizeof(double));
        newairfoil->polars[i].CD = (double*) malloc(size_alpha*sizeof(double));
        newairfoil->polars[i].size = size_alpha;
        for (int j=0; j<size_alpha; ++j) {
            //linear CL
            double CL = CL0 + CL_a * deg2rad(alpha[j]);     //neglecting beta
            if (CL > CLmax) {
                //clip at stall
                CL = CLmax;
            }
            else if (CL < CLmin) {
                CL = CLmin;
            }

            //quadratic CD
            double CD2 = (CL >= CLCD0)? CD2u : CD2l;
            double CD = (CD0 + CD2*(CL-CLCD0)*(CL-CLCD0)) * pow(Re[i]/REref, REexp);
            if (CL == CLmax || CL == CLmin) {
                //post-stall contribution to reach CD=2.0 at alpha=90°
                double aCD0 = (CLCD0 - CL0) / CL_a;
                CD += 2 * pow(sin(deg2rad(alpha[j]) - aCD0), 2);
            }
            newairfoil->polars[i].alpha[j] = deg2rad(alpha[j]);
            newairfoil->polars[i].CL[j] = CL;
            newairfoil->polars[i].CD[j] = CD;
        }
    }
    return newairfoil;
}

//linear interpolation between two points (x1,y1)-(x2,y2)
//INTERNAL USE ONLY
double interp1(double x1, double y1, double x2, double y2, double xq) {
    if (x2 == x1) {
        return y1;
    }
    return y1 + (xq-x1)*(y2-y1)/(x2-x1);
}

//data structure of a polar point
//INTERNAL USE ONLY
typedef struct {
    double alpha;
    double CL;
    double CD;
} PolarPoint;

//interpolate airfoil coefficient across a polar
//INTERNAL USE ONLY
PolarPoint* interpolate_polar(Polar *currentpolar, double alpha) {
    PolarPoint* query = malloc(sizeof(PolarPoint));
    if (!query) {
        printf("ERROR: memory allocation error in interpolate_polar()\n");
        return NULL;
    }
    query->alpha = alpha;
    query->CL = 0.0;
    query->CD = 0.0;

    if (alpha <= currentpolar->alpha[0]) {
        //below minimum AoA
        //interpolate to retrieve CD=2.0 at alpha=-90°
        query->CL = currentpolar->CL[0];
        query->CD = interp1(
            -M_PI/2,
            2.0,
            currentpolar->alpha[0],
            currentpolar->CD[0],
            alpha
        );
        //ALTERNATIVE: constant cap on the left
        //query->CL = currentpolar->CL[0];
        //query->CD = currentpolar->CD[0];
        return query;
    }
    else if (alpha > currentpolar->alpha[currentpolar->size-1]) {
        //above maximum AoA
        //interpolate to retrieve CD=2.0 at alpha=+90°
        query->CL = currentpolar->CL[currentpolar->size-1];
        query->CD = interp1(
            currentpolar->alpha[currentpolar->size-1],
            currentpolar->CD[currentpolar->size-1],
            M_PI/2,
            2.0,
            alpha
        );
        //ALTERNATIVE: constant cap on the right
        //query->CL = currentpolar->CL[currentpolar->size-1];
        //query->CD = currentpolar->CD[currentpolar->size-1];
        return query;
    }
    
    //interpolate between two alpha
    for (int i=1; i<(currentpolar->size); ++i) {
        if (currentpolar->alpha[i-1] < alpha && alpha <= currentpolar->alpha[i]) {
            query->CL = interp1(
                currentpolar->alpha[i-1],       //x1
                currentpolar->CL[i-1],          //y1
                currentpolar->alpha[i],         //x2
                currentpolar->CL[i],            //y2
                alpha                           //xq
            );
            query->CD = interp1(
                currentpolar->alpha[i-1],       //x1
                currentpolar->CD[i-1],          //y1
                currentpolar->alpha[i],         //x2
                currentpolar->CD[i],            //y2
                alpha                           //xq
            );
            break;
        }
    }
    return query;
}

//interpolate airfoil polars
//INTERNAL USE ONLY
PolarPoint* interpolate_airfoil_polars(Airfoil *currentairfoil, double alpha, double Re, double Mach) {
    //find the two polars that bracket the query point
    PolarPoint* query = malloc(sizeof(PolarPoint));
    if (!query) {
        printf("ERROR: memory allocation error in interpolate_polar()\n");
        return NULL;
    }
    query->alpha = alpha;
    query->CL = 0.0;
    query->CD = 0.0;

    int lower_polar_idx = 0;
    int upper_polar_idx = currentairfoil->size - 1;
    if (Re <= currentairfoil->polars[0].Re) {
        //use the lowest polar
        upper_polar_idx = 0;
    }
    else if (Re > currentairfoil->polars[currentairfoil->size-1].Re) {
        //use the highest polar
        lower_polar_idx = currentairfoil->size - 1;
    }
    else {
        //interpolate between two polars
        for (int i=1; i<(currentairfoil->size); ++i) {
            if (Re > currentairfoil->polars[i-1].Re && Re <= currentairfoil->polars[i].Re) {
                lower_polar_idx = i-1;
                upper_polar_idx = i;
                break;
            }
        }
    }

    //interpolate across alpha at the lower and upper polars
    PolarPoint* lower = interpolate_polar(&(currentairfoil->polars[lower_polar_idx]), alpha);
    PolarPoint* upper = interpolate_polar(&(currentairfoil->polars[upper_polar_idx]), alpha);

    //interpolate across Re
    query->CL = interp1(
        currentairfoil->polars[lower_polar_idx].Re,     //x1
        lower->CL,                                      //y1
        currentairfoil->polars[upper_polar_idx].Re,     //x2
        upper->CL,                                      //y2
        Re                                              //xq
    );
    query->CD = interp1(
        currentairfoil->polars[lower_polar_idx].Re,     //x1
        lower->CD,                                      //y1
        currentairfoil->polars[upper_polar_idx].Re,     //x2
        upper->CD,                                      //y2
        Re                                              //xq
    );

    //optional: correct for Mach number using the Prantdl-Meyer compressibility factor
    //set Mach = 0 to disable correction
    if (Mach > 0.0 && Mach < 0.99){
        query->CL = query->CL / sqrt(1.0 - Mach*Mach);
        //do not apply correction when Mach number exceeds 1
        //no warning will be issued, as this call may be part of an inner iteration
        //it is the user's responsibility to perform a sanity check on the final result
    }
    return query;
}

//read propeller geometry from APC PE0 file
Rotor* import_rotor_geometry_apc(const char *filename, Airfoil *airfoil) {
    Rotor* newrotor = malloc(sizeof(Rotor));
    if (!newrotor) {
        printf("ERROR: memory allocation error in import_rotor_geometry_apc()\n");
        return NULL;
    }
    newrotor->D = 0.0;
    newrotor->B = 0;
    newrotor->nelems = 0;
    newrotor->elements = NULL;

    FILE* fileio = fopen(filename, "rb");
    if (!fileio) {
        printf("ERROR opening file %s\n", filename);
        free(newrotor);
        return NULL;
    }

    //read file line by line
    char line[MAX_LINE_LENGTH];
    int parse_line = false;
    double rprev = 0.0;
    double cprev = 0.0;
    double betaprev = 0.0;
    while (fgets(line, MAX_LINE_LENGTH, fileio)) {
        //check if line contains unique keywords like "STATION" and "MAX-THICK"
        //to start parsing from the next line
        if (!parse_line && strstr(line, "STATION") && strstr(line, "MAX-THICK")) {
            //printf("Enable parse line\n");
            parse_line = true;
        }

        //count number of items in the line
        int token_counter = 0;
        if (parse_line) {
            bool in_value = false;      //keep track if current char is a value
            if (!isblank(line[0]) && isgraph(line[0])) {
                //printf("Starting line in value\n");
                in_value = true;
                token_counter += 1;
            }
            for (int i=1; i<MAX_LINE_LENGTH; ++i) {
                if (line[i] == '\0' || line[i] == '\n') {
                    break;
                }
                
                if (!isblank(line[i]) && isgraph(line[i])) {
                    if (!in_value) {
                        token_counter += 1;
                        //printf("New token starting from: %c (position: %i)\n", line[i],i);
                        in_value = true;
                    }
                }
                else {
                    if (in_value) {
                        in_value = false;
                    }
                }
            }
            //printf("Number of tokens: %i\n", token_counter);
        }

        //check if line is no longer valid for parsing
        //note that the lines containing the header and the units of the table must be skipped
        if (parse_line && token_counter > 2
                && !strstr(line, "STATION") && !strstr(line, "MAX-THICK")       //skip header line
                && !strstr(line, "(QUOTED)") && !strstr(line, "(LE-TE)")) {     //skip units line
            for (int i=0; i<MAX_LINE_LENGTH; ++i) {
                if (line[i] == '\0') {
                    break;
                }

                //if (isalpha(line[i]) || ispunct(line[i])) {
                if (!isdigit(line[i]) && line[i] != '.' && line[i] != '-' && line[i] != 'e' && isgraph(line[i])) {
                    //printf("Disable parse line at char %c\n", line[i]);
                    parse_line = false;
                    break;
                }
            }
        }

        //parse line
        if (parse_line && token_counter == 13) {
            //extract new values at the current section
            double r = rprev;
            double c = cprev;
            double beta = betaprev;
            if (sscanf(line, "%lf %lf %*f %*f %*f %*f %*f %lf %*f %*f %*f %*f %*f", &r, &c, &beta) == 3) {
                //convert units to SI
                r = r * 0.0254;
                c = c * 0.0254;
                beta = deg2rad(beta);

                //create new element averaging the new values with the previous ones
                if (rprev != 0.0) {
                    Element newelement; //= {0, 0, 0, 0, (*airfoil)};
                    newelement.r = 0.5*(r + rprev);
                    newelement.c = 0.5*(c + cprev);
                    newelement.beta = 0.5*(beta + betaprev);
                    newelement.dr = r - rprev;
                    newelement.airfoil = (*airfoil);
                    newrotor->elements = (Element*) realloc(newrotor->elements, (newrotor->nelems+1)*sizeof(Element));
                    newrotor->D = 2*r;
                    newrotor->nelems += 1;
                    newrotor->elements[newrotor->nelems-1] = newelement;
                }

                //update previous values for the next line
                rprev = r;
                cprev = c;
                betaprev = beta;
            }
        }

        //read number of blades
        if (newrotor->B == 0 && strstr(line, "BLADES:")) {
            char* token = strtok(line, " ");
            if (strcmp(token, "BLADES:") == 0) {
                token = strtok(NULL, " ");              //get the next token
                newrotor->B = atof(token);
            }
        }
    }
    fclose(fileio);
    if (newrotor->nelems == 0 || newrotor->D == 0 || newrotor->B == 0) {
        printf("ERROR unable to parse rotor from %s\n", filename);
        free(newrotor->elements);
        free(newrotor);
        return NULL;
    }
    return newrotor;
}

//free allocated memory on a Rotor
void free_rotor(Rotor *currentrotor) {
    free(currentrotor->elements);
    free(currentrotor);
}

//data structure for the residual output
//INTERNAL USE ONLY
typedef struct {
    double residual;
    double W;
    double phi;
    double Gamma;
    double lambdaw;
    double va;
    double vt;
    double Cn;
    double Ct;
} Residual;

//define the QProp residual function
//NOTE: the implementation is an exact replica of the steps described in the QProp theory document
//INTERNAL USE ONLY
void residual(Residual* output, double psi, double Ua, double Ut, double R, double B, Element *currentelement, double rho, double mu, double a) {
    //calculate velocity components
    double U = sqrt(Ua*Ua + Ut*Ut);
    double Wa = 0.5*Ua + 0.5*U*sin(psi);
    double Wt = 0.5*Ut + 0.5*U*cos(psi);
    //output = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0};
    output->va = Wa - Ua;
    output->vt = Ut - Wt;

    //determine relative wind velocity and angle of attack
    output->W = sqrt(Wa*Wa + Wt*Wt);
    double Re = rho * output->W * (currentelement->c) / mu;
    output->phi = atan(Wa/Wt);
    double alpha = currentelement->beta - output->phi;

    //interpolate airfoil aerodynamic coefficients
    double Mach = (a > 0)? sqrt(output->W/a) : 0.0;
    PolarPoint* operatingpoint = interpolate_airfoil_polars(&(currentelement->airfoil), alpha, Re, Mach);

    //calculate tip losses
    output->lambdaw = ((currentelement->r)/R)*(Wa/Wt);
    double f = (1.0 - (currentelement->r)/R) * 0.5 * B / output->lambdaw;
    double F = acos(exp(-f)) * 2.0 / M_PI;

    //determine circulation and rotor coefficients
    output->Gamma = output->vt * (4.0*M_PI*(currentelement->r) / B) * F * sqrt(1.0 + pow(4*output->lambdaw*R/(M_PI*B*(currentelement->r)), 2));
    output->residual = output->Gamma - 0.5 * output->W * (currentelement->c) * operatingpoint->CL;
    output->Cn = operatingpoint->CL* Wt / output->W - operatingpoint->CD * Wa / output->W;
    output->Ct = operatingpoint->CL* Wa / output->W + operatingpoint->CD * Wt / output->W;
    //return output;
}

/*
//find the root of a function f(x)=0 using the bisection method
//INTERNAL USE ONLY
double fzero(double (*f)(double), double a, double b, double tol, int itmax) {
    double fa = f(a);
    double fb = f(b);
    if (fa*fb > 0) {
        printf("ERROR when using fzero: f(a) and f(b) must have opposite signs\n");
        return 0;
    }

    //iterate
    double c = 0;
    double fc = 0;
    for (int i=0; i<itmax; ++i) {
        //evaluate mid point
        c = 0.5*(a+b);
        fc = f(c);
        //if (fabs(fc) <= tol) {                    //stopping criterion on residual only
        if (fabs(fc) <= tol && 0.5*(b-a) <= tol) {  //stopping criterion on residual and convergence
            return c;
        }

        //halve the domain
        if (fa*fc < 0) {
            b = c;
            fb = fc;
        }
        else {
            a = c;
            fa = fc;
        }
    }

    printf("ERROR while using fzero: maximum number of iterations reached\n");
    return 0;
}
*/

//run qprop iterations
RotorPerformance* qprop(Rotor *rotor, double Uinf, double Omega, double tol, int itmax, double rho, double mu, double a) {
    //initialize variables
    //RotorPerformance currentperformance;
    RotorPerformance* currentperformance = malloc(sizeof(RotorPerformance));
    if (!currentperformance) {
        printf("ERROR: memory allocation error in qprop()\n");
        return NULL;
    }
    currentperformance->T = 0.0;
    currentperformance->Q = 0.0;
    currentperformance->CT = 0.0;
    currentperformance->CP = 0.0;
    currentperformance->J = 0.0;
    currentperformance->residuals = (double*) malloc(rotor->nelems*sizeof(double));
    currentperformance->Gamma = (double*) malloc(rotor->nelems*sizeof(double));
    currentperformance->lambdaw = (double*) malloc(rotor->nelems*sizeof(double));
    currentperformance->r = (double*) malloc(rotor->nelems*sizeof(double));
    currentperformance->W = (double*) malloc(rotor->nelems*sizeof(double));
    currentperformance->phi = (double*) malloc(rotor->nelems*sizeof(double));
    currentperformance->dTdr = (double*) malloc(rotor->nelems*sizeof(double));
    currentperformance->dQdr = (double*) malloc(rotor->nelems*sizeof(double));
    currentperformance->nelems = rotor->nelems;

    //iterate over each element in the blade
    for (int i=0; i<(rotor->nelems); ++i) {
        Element *currentelement = &rotor->elements[i];
        double psi1 = -M_PI/2;
        double psi2 = +M_PI/2;
        
        //use bisection method to find where psi is zeroing the residual function
        //Residual res = residual(psi1, Uinf, Omega*currentelement->r, rotor->D/2, rotor->B, currentelement, rho, mu, a);
        Residual* res = malloc(sizeof(Residual));
        residual(res, psi1, Uinf, Omega*currentelement->r, rotor->D/2, rotor->B, currentelement, rho, mu, a);
        double f1 = res->residual;

        //res = residual(psi2, Uinf, Omega*currentelement->r, rotor->D/2, rotor->B, currentelement, rho, mu, a);
        residual(res, psi2, Uinf, Omega*currentelement->r, rotor->D/2, rotor->B, currentelement, rho, mu, a);
        double f2 = res->residual;

        if (f1*f2 > 0) {
            printf("ERROR on element %i: res(a) and res(b) have the same sign\n", i);
            return currentperformance;
        }
        double c = 0;
        double fc = 1.0;
        for (int j=0; j<itmax; ++j) {
            c = 0.5*(psi1+psi2);
            //res = residual(c, Uinf, Omega*currentelement->r, rotor->D/2, rotor->B, currentelement, rho, mu, a);
            residual(res, c, Uinf, Omega*currentelement->r, rotor->D/2, rotor->B, currentelement, rho, mu, a);
            fc = res->residual;
            
            if (fabs(fc) <= tol && 0.5*(psi2-psi1) <= tol) {
                //printf("Element #%i - Converged after %i iterations (residual = %e)\n", i, j, fc);
                break;
            }
            if (f1*fc < 0) {
                psi2 = c;
                f2 = fc;
            }
            else {
                psi1 = c;
                f1 = fc;
            }
        }

        //calculate element thrust and torque
        currentperformance->residuals[i] = fc;
        currentperformance->Gamma[i] = res->Gamma;
        currentperformance->lambdaw[i] = res->lambdaw;
        currentperformance->r[i] = currentelement->r;
        currentperformance->W[i] = res->W;
        currentperformance->phi[i] = res->phi;
        currentperformance->dTdr[i] = 0.5 * rho * res->W * res->W * res->Cn * currentelement->c;
        currentperformance->dQdr[i] = 0.5 * rho * res->W * res->W * res->Ct * currentelement->c * currentelement->r;
        currentperformance->T += currentperformance->dTdr[i] * currentelement->dr;
        currentperformance->Q += currentperformance->dQdr[i] * currentelement->dr;
    }
    currentperformance->T *= rotor->B;       //total thrust (N)
    currentperformance->Q *= rotor->B;       //total torque (N-m)
    double n = Omega/(2*M_PI);              //number revolutions per second (rev/s)
    currentperformance->CT = currentperformance->T / (rho * pow(n,2) * pow(rotor->D,4));      //thrust coefficient
    double CQ = currentperformance->Q / (rho * pow(n,2) * pow(rotor->D,5));                  //torque coefficient
    currentperformance->CP = 2*M_PI * CQ;            //power coefficient
    currentperformance->J = Uinf / (n * rotor->D);   //advance ratio
    return currentperformance;
}

//free allocated memory on RotorPerformance
void free_rotor_performance(RotorPerformance *perf) {
    free(perf->residuals);
    free(perf->r);
    free(perf->dTdr);
    free(perf->dQdr);
    free(perf);
}
