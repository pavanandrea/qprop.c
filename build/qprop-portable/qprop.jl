#-------------------------------------------------------------------------------
#   A Julia wrapper for qprop.c
#
#   How to import:
#   include("path/to/qprop/qprop.jl");
#   import .QProp;
#
#   Author: Andrea Pavan
#   License: MIT
#-------------------------------------------------------------------------------
module QProp
export Polar, Airfoil, Section, Rotor, RotorPerformance,
       deg2rad, read_xfoil_polar_from_file, import_xfoil_polars,
       analytic_polar_curves, import_rotor_geometry_apc,
       import_rotor_geometry_uiuc, refine_rotor_sections, qprop;

#import precompiled shared library for the current operating system
lib_filename = "";
if Sys.iswindows()
    lib_filename = joinpath(@__DIR__, "qprop-lib-windows-x64.dll")
elseif Sys.isapple()
    lib_filename = joinpath(@__DIR__, "qprop-lib-macos-arm64.dylib")
elseif Sys.islinux()
    lib_filename = joinpath(@__DIR__, "qprop-lib-linux-x64.so")
else
    error("ERROR in qprop.jl: the available shared libraries do not support the current operating system")
end
if !isfile(lib_filename)
    error("ERROR in qprop.jl: unable to find shared library");
end


#----------------------
#   DATA STRUCTURES
#----------------------


#data structure for polars
struct CPolar
    Re::Cdouble
    alpha_ptr::Ptr{Cdouble}
    CL_ptr::Ptr{Cdouble}
    CD_ptr::Ptr{Cdouble}
    size::Cint
end
struct Polar
    Re::Float64
    alpha::Vector{Float64}
    CL::Vector{Float64}
    CD::Vector{Float64}
    size::Int
end

#data structure for airfoils
struct CAirfoil
    polars_ptr::Ptr{CPolar}
    size::Cint
end
struct Airfoil
    polars::Vector{Polar}
    size::Int
end

#data structure for blade sections
struct CSection
    c::Cdouble
    beta::Cdouble
    r::Cdouble
    airfoil::CAirfoil
end
struct Section
    c::Float64
    beta::Float64
    r::Float64
    airfoil::Airfoil
end

#data structure for rotors
struct CRotor
    D::Cdouble
    B::Cint
    nsections::Cint
    sections_ptr::Ptr{CSection}
end
struct Rotor
    D::Float64
    B::Int
    nsections::Int
    sections::Vector{Section}
end

#data structure for qprop output
struct CRotorPerformance
    T::Cdouble
    Q::Cdouble
    CT::Cdouble
    CP::Cdouble
    J::Cdouble
    residuals_ptr::Ptr{Cdouble}
    Gamma_ptr::Ptr{Cdouble}
    lambdaw_ptr::Ptr{Cdouble}
    r_ptr::Ptr{Cdouble}
    W_ptr::Ptr{Cdouble}
    phi_ptr::Ptr{Cdouble}
    dTdr_ptr::Ptr{Cdouble}
    dQdr_ptr::Ptr{Cdouble}
    nelems::Cint
end
struct RotorPerformance
    T::Float64
    Q::Float64
    CT::Float64
    CP::Float64
    J::Float64
    residuals::Vector{Float64}
    Gamma::Vector{Float64}
    lambdaw::Vector{Float64}
    r::Vector{Float64}
    W::Vector{Float64}
    phi::Vector{Float64}
    dTdr::Vector{Float64}
    dQdr::Vector{Float64}
    nelems::Int
end


#----------------------------
#   FUNCTION DECLARATIONS
#----------------------------


"""
DEG2RAD converts degrees to radians
Input:
    - deg (double): angle in degrees
Output:
    - (double): angle in radians
Example:
    myangle = deg2rad(+45.0);
"""
function deg2rad(rad)
    return ccall(
        (:deg2rad, lib_filename),                       #C function
        Float64,                                        #return type
        (Float64,),                                     #parameters types
        rad                                             #parameters
    );
end


"""
FREE_POLAR frees the memory allocated in a CPolar structure
Input:
    - currentpolar (Ptr{CPolar}): data structure that is no longer needed
Output:
    - none
"""
function free_polar(currentpolar::Ptr{CPolar})
    ccall(
        (:free_polar, lib_filename),    #C function
        Cvoid,                          #return type
        (Ptr{CPolar},),                 #parameters types
        currentpolar                    #parameters
    );
    return;
end


#convert CPolar to Polar
function cpolar2polar(cpolar::CPolar)
    newpolar = Polar(cpolar.Re, zeros(cpolar.size), zeros(cpolar.size), zeros(cpolar.size), cpolar.size);
    for i=1:cpolar.size
        newpolar.alpha[i] = unsafe_load(cpolar.alpha_ptr, i);
        newpolar.CL[i] = unsafe_load(cpolar.CL_ptr, i);
        newpolar.CD[i] = unsafe_load(cpolar.CD_ptr, i);
    end
    return newpolar;
end


"""
READ_XFOIL_POLAR_FROM_FILE reads an airfoil polar from a text file
Input:
    - filename: name of the txt file containing the polar data
Output:
    - (Polar): data structure containing the polar data
Notes:
    - The file is assumed to be in the XFoil/XFLR5 format:
        - Reynolds number on a line containing "Re =", ignoring spaces
        - A table of alpha, CL and CD values, ordered by alpha (from min to max)
        - Alpha values in the first column, CL in the second and CD in the third
        - No empty lines between values in the table
    - The file content is not thoroughly checked for errors
    - This function internally allocates memory for the CPolar structure arrays
      alpha, CL and CD using malloc and realloc.
      It is the caller's responsibility to free this memory by calling
      unload_polar_from_memory(CPolar) when it is no longer needed
Example:
    mypolar = read_xfoil_polar_from_file("naca4412_Re0.030_M0.00_N6.0.txt");
"""
function read_xfoil_polar_from_file(filename::String)
    #get polar in C format
    cpolar_ptr = ccall(
        (:read_xfoil_polar_from_file, lib_filename),    #C function
        Ptr{CPolar},                                    #return type
        (Ptr{UInt8},),                                  #parameters types
        filename                                        #parameters
    );

    #convert to Julia format
    if cpolar_ptr == C_NULL
        error("ERROR in read_xfoil_polar_from_file(): failed to read polar from file");
    end
    cpolar = unsafe_load(cpolar_ptr);
    newpolar = cpolar2polar(cpolar);

    #unload polar in C format from memory
    free_polar(cpolar_ptr);
    return newpolar;
end


"""
FREE_AIRFOIL frees the memory allocated in an CAirfoil structure
Input:
    - currentairfoil (CAirfoil): data structure that is no longer needed
Output:
    - none
"""
function free_airfoil(currentairfoil::Ptr{CAirfoil})
    ccall(
        (:free_airfoil, lib_filename),      #C function
        Cvoid,                              #return type
        (Ptr{CAirfoil},),                   #parameters types
        currentairfoil                      #parameters
    );
    return;
end


#convert CAirfoil to Airfoil
function cairfoil2airfoil(cairfoil::CAirfoil)
    newairfoil = Airfoil(Vector{Polar}(undef,cairfoil.size), cairfoil.size);
    for i=1:cairfoil.size
        #extract i-th polar
        cpolari = unsafe_load(cairfoil.polars_ptr, i);
        newairfoil.polars[i] = cpolar2polar(cpolari);
    end
    return newairfoil;
end

#convert Airfoil to CAirfoil
function airfoil2cairfoil(airfoil::Airfoil)
    cpolars = Vector{CPolar}(undef, airfoil.size);
    for i=1:airfoil.size
        cpolars[i] = CPolar(
            airfoil.polars[i].Re,
            pointer(airfoil.polars[i].alpha),
            pointer(airfoil.polars[i].CL),
            pointer(airfoil.polars[i].CD),
            airfoil.polars[i].size
        );
    end
    cairfoil = CAirfoil(pointer(cpolars), airfoil.size);
    return cairfoil;
end


"""
IMPORT_XFOIL_POLARS imports airfoil polars from multiple text files
Input:
    - filenames: list of files containing polar data
Output:
    - (Airfoil): data structure containing the imported airfoil polars
Notes:
    - All files are assumed to be in the XFoil/XFLR5 format
      (see the notes above "read_xfoil_polar_from_file")
    - Safety checks on user input are not implemented yet
    - The content of each file is not checked
    - This function internally allocates memory for the CAirfoil structure arrays
      and for each CPolar using malloc and realloc.
      It is the caller's responsibility to free this memory when it is no longer
      needed, by calling unload_airfoil_from_memory(CAirfoil)
Example:
    filenames = [
        "naca4412_Re0.030_M0.00_N6.0.txt",
        "naca4412_Re0.060_M0.00_N6.0.txt"
    ];
    myairfoil = import_xfoil_polars(filenames);
"""
function import_xfoil_polars(filenames::Vector{String})
    #get airfoil in C format
    cairfoil_ptr = ccall(
        (:import_xfoil_polars, lib_filename),           #C function
        Ptr{CAirfoil},                                  #return type
        (Ptr{Ptr{UInt8}}, Int32),                       #parameters types
        filenames, length(filenames)                    #parameters
    );

    #convert to Julia format
    if cairfoil_ptr == C_NULL
        error("ERROR in import_xfoil_polars(): failed to read airfoil polars");
    end
    cairfoil = unsafe_load(cairfoil_ptr);
    newairfoil = cairfoil2airfoil(cairfoil);

    #unload airfoil in C format from memory
    free_airfoil(cairfoil_ptr);
    return newairfoil;
end


"""
ANALYTIC_POLAR_CURVES generates polars using the simple analytic model
described by Drela in the QPROP user guide
Input:
    - CL0: zero-lift lift coefficient
    - CL_a: lift curve slope
    - CLmin: minimum lift coefficient
    - CLmax: maximum lift coefficient
    - CD0: zero-lift drag coefficient
    - CD2u: quadratic coefficient in the drag formula
    - CD2l: quadratic coefficient in the drag formula
    - CLCD0: lift coefficient at minimum drag
    - REref: reference Reynolds number for all the coefficients above
    - REexp: Reynolds number exponent (default: -0.5)
Output:
    - (CAirfoil): generated polar curves
Example:
    myairfoil = analytic_polar_curves(
        0.50, 5.8, -0.3, 1.2,   0.028, 0.050, 0.020, 0.5,   70000, -0.7
    );
"""
function analytic_polar_curves(CL0::Float64, CL_a::Float64, CLmin::Float64, CLmax::Float64,
                               CD0::Float64, CD2u::Float64, CD2l::Float64, CLCD0::Float64,
                               REref::Float64, REexp::Float64=-0.5)
    #get airfoil in C format
    cairfoil_ptr = ccall(
        (:analytic_polar_curves, lib_filename),         #C function
        Ptr{CAirfoil},                                  #return type
        (Float64, Float64, Float64, Float64, Float64, Float64, Float64, Float64, Float64, Float64),     #parameters types
        CL0, CL_a, CLmin, CLmax, CD0, CD2u, CD2l, CLCD0, REref, REexp                                   #parameters
    );

    #convert to Julia format
    cairfoil = unsafe_load(cairfoil_ptr);
    newairfoil = cairfoil2airfoil(cairfoil);

    #unload airfoil in C format from memory
    free_airfoil(cairfoil_ptr);
    return newairfoil;
end


"""
FREE_ROTOR frees the memory allocated in a CRotor structure
Input:
    - currentrotor (CRotor): data structure that is no longer needed
Output:
    - none
"""
function free_rotor(currentrotor::Ptr{CRotor})
    ccall(
        (:free_rotor, lib_filename),        #C function
        Cvoid,                              #return type
        (Ptr{CRotor},),                     #parameters types
        currentrotor                        #parameters
    );
    return;
end


"""
IMPORT_ROTOR_GEOMETRY_APC reads a propeller geometry from an APC PE0 file
Input:
    - filename: name of the PE0 file containing the geom data
    - airfoil (Airfoil): data structure containing the airfoil data
Output:
    - (Rotor): imported rotor geometry with the given airfoil
Notes:
    - the file is assumed to be downloaded from the official APC website
Example:
    filenames = ["naca4412_Re0.100_M0.00_N6.0.txt"];
    myairfoil = import_xfoil_polars(filenames, 1);
    myrotor = import_rotor_geometry_apc("10x7SF-PERF.PE0", myairfoil);
"""
function import_rotor_geometry_apc(filename::String, airfoil::Airfoil)
    #convert airfoil to C format
    cairfoil = airfoil2cairfoil(airfoil);

    #get rotor in C format
    crotor_ptr = ccall(
        (:import_rotor_geometry_apc, lib_filename),     #C function
        Ptr{CRotor},                                    #return type
        (Ptr{UInt8}, Ptr{CAirfoil}),                    #parameters types
        filename, Ref(cairfoil)                         #parameters
    );
    if crotor_ptr == C_NULL
        error("ERROR in import_rotor_geometry_apc(): failed to read geometry from file");
    end
    crotor = unsafe_load(crotor_ptr);

    #convert to Julia format
    newrotor = Rotor(crotor.D, crotor.B, crotor.nsections, Vector{Section}(undef, crotor.nsections));
    for i=1:crotor.nsections
        #extract i-th section in C format
        csecti = unsafe_load(crotor.sections_ptr, i);

        #convert i-th section to Julia format
        newrotor.sections[i] = Section(
            csecti.c,
            csecti.beta,
            csecti.r,
            cairfoil2airfoil(csecti.airfoil)
        );
    end

    #clean memory
    free_rotor(crotor_ptr);
    return newrotor;
end


"""
IMPORT_ROTOR_GEOMETRY_UIUC reads a propeller geometry from an UIUC txt file
Input:
    - filename: name of the txt file containing the geom data
    - airfoil (Airfoil): data structure containing the airfoil data
    - D: rotor diameter (m)
    - B: number of blades
Output:
    - (Rotor): imported rotor geometry with the given properties
Notes:
    - the file is assumed to be downloaded from the UIUC website
Example:
    airfoil_filenames = ["naca4412_Re0.100_M0.00_N6.0.txt"];
    myairfoil = import_xfoil_polars(airfoil_filenames);
    myrotor = import_rotor_geometry_uiuc("apcsf_10x7_geom.txt", myairfoil, 10*0.0254, 2);
"""
function import_rotor_geometry_uiuc(filename::String, airfoil::Airfoil, D::Float64, B::Int)
    #convert airfoil to C format
    cairfoil = airfoil2cairfoil(airfoil);

    #get rotor in C format
    crotor_ptr = ccall(
        (:import_rotor_geometry_uiuc, lib_filename),    #C function
        Ptr{CRotor},                                    #return type
        (Ptr{UInt8}, Ptr{CAirfoil}, Float64, Int),      #parameters types
        filename, Ref(cairfoil), D, B                   #parameters
    );
    if crotor_ptr == C_NULL
        error("ERROR in import_rotor_geometry_uiuc(): failed to read geometry from file");
    end
    crotor = unsafe_load(crotor_ptr);

    #convert to Julia format
    newrotor = Rotor(crotor.D, crotor.B, crotor.nsections, Vector{Section}(undef, crotor.nsections));
    for i=1:crotor.nsections
        #extract i-th section in C format
        csecti = unsafe_load(crotor.sections_ptr, i);

        #convert i-th section to Julia format
        newrotor.sections[i] = Section(
            csecti.c,
            csecti.beta,
            csecti.r,
            cairfoil2airfoil(csecti.airfoil)
        );
    end

    #clean memory
    free_rotor(crotor_ptr);
    return newrotor;
end


"""
REFINE_ROTOR_SECTIONS creates a propeller geometry with the specified number
of equally-spaced sections
Input:
    - oldrotor (Rotor): reference rotor geometry
    - nsections: desired number of equally-spaced sections
Output:
    - (Rotor): refined rotor geometry
Example:
    airfoil_filenames = ["naca4412_Re0.100_M0.00_N6.0.txt"];
    myairfoil = import_xfoil_polars(airfoil_filenames);
    reference_rotor = import_rotor_geometry_uiuc("apcsf_10x7_geom.txt", myairfoil, 10*0.0254, 2);
    myrotor = refine_rotor_sections(reference_rotor, 100);
"""
function refine_rotor_sections(oldrotor::Rotor, nsections::Int)
    #convert rotor in C format
    coldsections = Vector{CSection}(undef, oldrotor.nsections);
    for i=1:oldrotor.nsections
        coldsections[i] = CSection(
            oldrotor.sections[i].c,
            oldrotor.sections[i].beta,
            oldrotor.sections[i].r,
            airfoil2cairfoil(oldrotor.sections[i].airfoil)
        );
    end
    coldrotor = CRotor(oldrotor.D, oldrotor.B, oldrotor.nsections, pointer(coldsections));

    #get output in C format
    cnewrotor_ptr = ccall(
        (:refine_rotor_sections, lib_filename),             #C function
        Ptr{CRotor},                                        #return type
        (Ptr{CRotor}, Int),                                 #parameters types
        Ref(coldrotor), nsections                           #parameters
    );
    if cnewrotor_ptr == C_NULL
        error("ERROR in refine_rotor_sections(): failed to discretize geometry");
    end
    cnewrotor = unsafe_load(cnewrotor_ptr);

    #convert to Julia format
    newrotor = Rotor(cnewrotor.D, cnewrotor.B, cnewrotor.nsections, Vector{Section}(undef, cnewrotor.nsections));
    for i=1:cnewrotor.nsections
        #extract i-th section in C format
        csecti = unsafe_load(cnewrotor.sections_ptr, i);

        #convert i-th section to Julia format
        newrotor.sections[i] = Section(
            csecti.c,
            csecti.beta,
            csecti.r,
            cairfoil2airfoil(csecti.airfoil)
        );
    end
    
    #clean memory
    free_rotor(cnewrotor_ptr);
    return newrotor;
end


"""
FREE_ROTOR_PERFORMANCE frees the memory allocated in a qprop output
Input:
    - perf (Ptr{CRotorPerformance}): qprop output that is no longer needed
Output:
    - none
"""
function free_rotor_performance(perf::Ptr{CRotorPerformance})
    ccall(
        (:free_rotor_performance, lib_filename),    #C function
        Cvoid,                                      #return type
        (Ptr{CRotorPerformance},),                  #parameters types
        perf                                        #parameters
    );
    return;
end


"""
QPROP runs the QProp algorithm as described by Drela for each blade element
Input:
    - rotor (Rotor): struct containing the rotor data
    - Uinf: freestream velocity in m/s
    - Omega: rotor speed in rad/s
    - tol: stopping criterion tolerance (default value: 1e-6)
    - itmax: maximum number of iterations (default value: 100)
    - rho: air density in kg/m3 (default value: 1.225)
    - mu: air dynamic viscosity in Pa-s (default value: 1.81e-5)
    - a: speed of sound in m/s (default value: 0.0) - set to 0 to disable Mach correction)
Output:
    - (RotorPerformance): data structure containing the QProp outputs
Notes:
    - the current implementation assumes that there is no externally-induced
      tangential velocity (Ut = 0)
"""
function qprop(rotor::Rotor, Uinf::Float64, Omega::Float64, tol::Float64=1e-6, itmax::Int=100, rho::Float64=1.225, mu::Float64=1.81e-5, a::Float64=0.0)
    #convert rotor in C format
    csections = Vector{CSection}(undef, rotor.nsections);
    for i=1:rotor.nsections
        csections[i] = CSection(
            rotor.sections[i].c,
            rotor.sections[i].beta,
            rotor.sections[i].r,
            airfoil2cairfoil(rotor.sections[i].airfoil)
        );
    end
    crotor = CRotor(rotor.D, rotor.B, rotor.nsections, pointer(csections));

    #get output in C format
    cperf_ptr = ccall(
        (:qprop, lib_filename),                                                     #C function
        Ptr{CRotorPerformance},                                                     #return type
        (Ptr{CRotor}, Float64, Float64, Float64, Int, Float64, Float64, Float64),   #parameters types
        Ref(crotor), Uinf, Omega, tol, itmax, rho, mu, a                            #parameters
    );
    if cperf_ptr == C_NULL
        error("ERROR in qprop(): failed to run qprop iterations");
    end
    cperf = unsafe_load(cperf_ptr);

    #convert to Julia format
    residuals = [unsafe_load(cperf.residuals_ptr, i) for i=1:cperf.nelems];
    Gamma = [unsafe_load(cperf.Gamma_ptr, i) for i=1:cperf.nelems];
    lambdaw = [unsafe_load(cperf.lambdaw_ptr, i) for i=1:cperf.nelems];
    r = [unsafe_load(cperf.r_ptr, i) for i=1:cperf.nelems];
    W = [unsafe_load(cperf.W_ptr, i) for i=1:cperf.nelems];
    phi = [unsafe_load(cperf.phi_ptr, i) for i=1:cperf.nelems];
    dTdr = [unsafe_load(cperf.dTdr_ptr, i) for i=1:cperf.nelems];
    dQdr = [unsafe_load(cperf.dQdr_ptr, i) for i=1:cperf.nelems];
    perf = RotorPerformance(cperf.T, cperf.Q, cperf.CT, cperf.CP, cperf.J, residuals, Gamma, lambdaw, r, W, phi, dTdr, dQdr, cperf.nelems);

    #clean memory
    free_rotor_performance(cperf_ptr);
    return perf;
end

end #module
