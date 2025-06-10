%--------------------------------------------------------------------------
%   This script uses qprop.c to analyze the APC 10x7SF propeller in
%   hovering conditions
%--------------------------------------------------------------------------
clear;
clc;
addpath('qprop-portable');


%% import precompiled library for the current operating system
lib_filename = '';
switch computer('arch')
    case 'win64'
        lib_filename = 'qprop-lib-windows-x64.dll';
    case 'maca64'
        lib_filename = 'qprop-lib-macos-arm64.dylib';
    case 'glnxa64'
        lib_filename = 'qprop-lib-linux-x64.so';
    otherwise
        error('The provided binaries do not support the current operating system');
end

if ~libisloaded(lib_filename)
    loadlibrary(lib_filename, 'qprop.h', 'alias', 'qprop');
end
% libfunctions('qprop')       %print available functions in qprop.c


%% define the airfoil characteristics of the propeller

%let's start by defining the airfoil characteristics of the propeller
%the easiest way to do this is by using the analytical model of QPROP
%the coefficients used below match those specified in the QPROP User Manual
% myairfoil_ptr = calllib('qprop', 'analytic_polar_curves', ...
%    0.50, 5.8, -0.3, 1.2, ...       %CL0, CL_a, CLmin, CLmax
%    0.028, 0.050, 0.020, 0.5, ...   %CD0, CD2u, CD2l, CLCD0
%    70000.0, -0.7 ...               %REref, REexp
% );

%ALTERNATIVE APPROACH: interpolate XFOIL/XFLR5 polars
%if you prefer to use pre-computed polars from XFOIL or XFLR5, you can import them instead
%to do this, specify a list of filenames in ascending order of the Reynolds number
%for example:
filenames = {
    fullfile('..','test','airfoil_polar_naca4412_Ncrit=6','NACA 4412_T1_Re0.030_M0.00_N6.0.txt');
    fullfile('..','test','airfoil_polar_naca4412_Ncrit=6','NACA 4412_T1_Re0.040_M0.00_N6.0.txt');
    fullfile('..','test','airfoil_polar_naca4412_Ncrit=6','NACA 4412_T1_Re0.060_M0.00_N6.0.txt');
    fullfile('..','test','airfoil_polar_naca4412_Ncrit=6','NACA 4412_T1_Re0.080_M0.00_N6.0.txt');
    fullfile('..','test','airfoil_polar_naca4412_Ncrit=6','NACA 4412_T1_Re0.100_M0.00_N6.0.txt');
    fullfile('..','test','airfoil_polar_naca4412_Ncrit=6','NACA 4412_T1_Re0.130_M0.00_N6.0.txt');
    fullfile('..','test','airfoil_polar_naca4412_Ncrit=6','NACA 4412_T1_Re0.160_M0.00_N6.0.txt');
    fullfile('..','test','airfoil_polar_naca4412_Ncrit=6','NACA 4412_T1_Re0.200_M0.00_N6.0.txt');
    fullfile('..','test','airfoil_polar_naca4412_Ncrit=6','NACA 4412_T1_Re0.300_M0.00_N6.0.txt');
    fullfile('..','test','airfoil_polar_naca4412_Ncrit=6','NACA 4412_T1_Re0.500_M0.00_N6.0.txt')
};
myairfoil_ptr = calllib('qprop', 'import_xfoil_polars', filenames, numel(filenames));

%NOTE that you can access the content of 'myairfoil_ptr' in MATLAB:
% myairfoil = myairfoil_ptr.Value;


%% define the geometry of the propeller

%let's continue by defining the geometry of the propeller
%if you want to analyze an APC propeller, the easiest way is to read its geometry from a file.
%for example, you can download a PE0 file from the APC website, then use the following function:
myrotor_ptr = calllib('qprop', 'import_rotor_geometry_apc', fullfile('..','validation/','apc_10x7sf/','10x7SF-PERF.PE0'), myairfoil_ptr);

%OR, if you want to import a propeller geometry from the UIUC database:
%myrotor_ptr = calllib('qprop', 'import_rotor_geometry_uiuc', fullfile('..','validation/','apc_10x7sf/','uiuc_data/','apcsf_10x7_geom.txt'), myairfoil_ptr, 10*0.0254, 2);

%NOTE: it is not currently possible to define the propeller geometry manually in MATLAB


%% run analysis

%specify freestream velocity (in m/s) in axial direction
Uinf = 0.00;

%specify rotor speed in rad/s
%remember to multiply by pi/30 to convert from rpm to rad/s
Omega = 14020 * pi/30;

%specify remaining parameters
tol = 1e-6;         %residual tolerance
itmax = 100;        %maximum number of iterations
rho = 1.225;        %air density (in kg/m3)
mu = 1.81e-5;       %air dynamic viscosity (in Pa-s)
a = 0.0;            %sound speed (in m/s, set to 0 to disable Mach effects)

%run qprop.c
results_ptr = calllib('qprop', 'qprop', myrotor_ptr, Uinf, Omega, tol, itmax, rho, mu, a);
results = results_ptr.Value;

%print the results of the analysis
fprintf("qprop.c results:\n");
fprintf("    Thrust: %.5f N\n", results.T);
fprintf("    Torque: %.5f N-m\n", results.Q);
%the expected output of the analysis is:
%qprop.c results:
%    Thrust: 44.57431 N
%    Torque: 0.75372 N-m


calllib('qprop', 'free_airfoil', myairfoil_ptr);
calllib('qprop', 'free_rotor', myrotor_ptr);
calllib('qprop', 'free_rotor_performance', results_ptr);
% clear('myairfoil_ptr');     %uncomment to avoid warning when unloading library
% clear('myrotor_ptr');
% clear('results_ptr');
unloadlibrary('qprop');
