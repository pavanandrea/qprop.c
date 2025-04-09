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

    This file is a header for the precompiled shared libraries,
    replicating the definitions in qprop.c.

    Author: Andrea Pavan
    License: MIT
*******************************************************************************/


//---------------------
//  DATA STRUCTURES
//---------------------


//data structure for polars
typedef struct {
    double Re;          //Reynolds number
    double* alpha;      //array of angle of attacks (rad)
    double* CL;         //array of lift coefficients - same size as alpha
    double* CD;         //array of drag coefficients - same size as alpha
    int size;           //number of points in the polar
} Polar;

//data structure for airfoils
typedef struct {
    Polar* polars;      //array of polars - typically at different Re
    int size;           //number of polars in the airfoil
} Airfoil;

//data structure for blade elements
typedef struct {
    double c;           //chord length (m)
    double beta;        //twist angle (rad)
    double r;           //radial distance (m)
    double dr;          //width length (m)
    Airfoil airfoil;    //local airfoil data
} Element;

//data structure for rotors
typedef struct {
    double D;           //rotor diameter (m)
    int B;              //number of blades
    int nelems;         //number of elements discretizing a blade
    Element *elements;  //array of elements discretizing a blade
} Rotor;

//data structure for qprop output
typedef struct {
    double T;           //overall thrust (N)
    double Q;           //overall torque (N-m)
    double CT;          //thrust coefficient
    double CP;          //power coefficient
    double J;           //advance ratio
    double *residuals;  //array of elements residuals
    double *Gamma;      //array of elements circulations
    double *lambdaw;    //array of local wake advance ratios
    double *r;          //array of elements radial distance (m)
    double *W;          //array of local velocities (m/s)
    double *phi;        //array of local inflow angle (rad)
    double *dTdr;       //array for blade thrust distribution (N/m)
    double *dQdr;       //array for blade torque distribution (N-m/m)
    int nelems;         //number of elements discretizing a blade
} RotorPerformance;



//---------------------------
//  FUNCTION DECLARATIONS
//---------------------------


//DEG2RAD converts degrees to radians
//Input:
//  - deg (double): angle in degrees
//Output:
//  - (double): angle in radians
double deg2rad(double deg);

//READ_XFOIL_POLAR_FROM_FILE reads an airfoil polar from a text file
//Input:
//  - filename (array of char): name of the txt file containing the polar data
//Output:
//  - (Polar*): pointer to the polar data
//Notes:
//  - The file is assumed to be in the XFoil/XFLR5 format:
//      - Reynolds number on a line containing "Re =", ignoring spaces
//      - A table of alpha, CL and CD values, ordered by alpha (from min to max)
//      - Alpha values in the first column, CL in the second and CD in the third
//      - No empty lines between values in the table
//  - The file content is not thoroughly checked for errors
//  - This function internally allocates memory for the Polar structure arrays
//    alpha, CL and CD using malloc and realloc.
//    It is the caller's responsibility to free this memory by calling
//    unload_polar_from_memory(Polar*) when it is no longer needed
Polar* read_xfoil_polar_from_file(const char *filename);

//FREE_POLAR frees the memory allocated in a Polar structure
//Input:
//  - currentpolar (Polar*): pointer to a polar that is no longer needed
//Output:
//  - none
void free_polar(Polar *currentpolar);

//FREE_AIRFOIL frees the memory allocated in an Airfoil structure
//Input:
//  - currentairfoil (Airfoil*): pointer to an airfoil that is no longer needed
//Output:
//  - none
void free_airfoil(Airfoil *currentairfoil);

//IMPORT_XFOIL_POLARS imports airfoil polars from multiple text files
//Input:
//  - filenames (array of (array of char)): list of files containing polar data
//  - number_of_files (int): number of files in the array
//Output:
//  - (Airfoil*): pointer to the imported airfoil polars
//Notes:
//  - All files are assumed to be in the XFoil/XFLR5 format
//    (see the notes above "read_xfoil_polar_from_file")
//  - Safety checks on user input are not implemented yet
//  - The content of each file is not checked
//  - This function internally allocates memory for the Airfoil structure arrays
//    and for each Polar using malloc and realloc.
//    It is the caller's responsibility to free this memory when it is no longer
//    needed, by calling unload_airfoil_from_memory(Airfoil*)
Airfoil* import_xfoil_polars(const char *filenames[], int number_of_files);

//ANALYTIC_POLAR_CURVES generates polars using the simple analytic model
//described by Drela in the QPROP user guide
//Input:
//  - CL0 (double): zero-lift lift coefficient
//  - CL_a (double): lift curve slope
//  - CLmin (double): minimum lift coefficient
//  - CLmax (double): maximum lift coefficient
//  - CD0 (double): zero-lift drag coefficient
//  - CD2u (double): quadratic coefficient in the drag formula
//  - CD2l (double): quadratic coefficient in the drag formula
//  - CLCD0 (double): lift coefficient at minimum drag
//  - REref (double): reference Reynolds number for all the coefficients above
//  - REexp (double): Reynolds number exponent (suggested: -0.5)
//Output:
//  - (Airfoil*): pointer to generated polar curves
Airfoil* analytic_polar_curves(double CL0, double CL_a, double CLmin, double CLmax,
                               double CD0, double CD2u, double CD2l, double CLCD0,
                               double REref, double REexp);

//IMPORT_ROTOR_GEOMETRY_APC reads a propeller geometry from an APC PE0 file
//Input:
//  - filename (array of char): name of the PE0 file containing the geom data
//  - airfoil (Airfoil*): pointer to an airfoil
//Output:
//  - (Rotor*): pointer to imported rotor geometry with the given airfoil
//Notes:
//  - the file is assumed to be downloaded from the official APC website
Rotor* import_rotor_geometry_apc(const char *filename, Airfoil *airfoil);

//FREE_ROTOR frees the memory allocated in a Rotor structure
//Input:
//  - currentrotor (Rotor*): pointer to a rotor that is no longer needed
//Output:
//  - none
void free_rotor(Rotor *currentrotor);

//QPROP runs the QProp algorithm as described by Drela for each blade element
//Input:
//  - rotor (Rotor*): pointer to a rotor
//  - Uinf (double): freestream velocity in m/s
//  - Omega (double): rotor speed in rad/s
//  - tol (double): stopping criterion tolerance (suggested value: 1e-6)
//  - itmax (int): maximum number of iterations (suggested value: 100)
//  - rho (double): air density in kg/m3 (suggested value: 1.225)
//  - mu (double): air dynamic viscosity in Pa-s (suggested value: 1.81e-5)
//  - a (double): speed of sound in m/s (suggested value: 340.0) - set to 0 to disable Mach correction
//Output:
//  - (RotorPerformance*): pointer to the QProp outputs
//Notes:
//  - the current implementation assumes that there is no externally-induced
//    tangential velocity (Ut = 0)
RotorPerformance* qprop(Rotor *rotor, double Uinf, double Omega, double tol, int itmax, double rho, double mu, double a);

//FREE_ROTOR_PERFORMANCE frees the memory allocated in a qprop output
//Input:
//  - perf (RotorPerformance*): pointer to a qprop output that is no longer needed
//Output:
//  - none
void free_rotor_performance(RotorPerformance *perf);
