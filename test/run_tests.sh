#!/bin/bash
#-------------------------------------------------------------------------------
#   This script compiles and runs all the tests in the current folder.
#   How to run:
#       ./run_tests.sh
#   You can also run valgrind checks by setting CHECK_MEMORY_LEAKS:
#       CHECK_MEMORY_LEAKS=true ./run_tests.sh
#
#   Author: Andrea Pavan
#   License: MIT
#-------------------------------------------------------------------------------

#check if the user provided the variable CHECK_MEMORY_LEAKS
CHECK_MEMORY_LEAKS=${CHECK_MEMORY_LEAKS:-false}
if "$CHECK_MEMORY_LEAKS" == true; then
    RUN_CMD="valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes"
else
    RUN_CMD=""
fi

#compile and run tests in C
gcc 01_test_fzero.c -o 01_test_fzero -lm -Wall -Wextra
$RUN_CMD ./01_test_fzero

gcc 02_test_import_xfoil_polars.c -o 02_test_import_xfoil_polars -lm -Wall -Wextra
$RUN_CMD ./02_test_import_xfoil_polars

gcc 03_test_interpolate_airfoil_polars.c -o 03_test_interpolate_airfoil_polars -lm -Wall -Wextra
$RUN_CMD ./03_test_interpolate_airfoil_polars

gcc 04_test_residual.c -o 04_test_residual -lm -Wall -Wextra
$RUN_CMD ./04_test_residual

gcc 05_test_qprop.c -o 05_test_qprop -lm -Wall -Wextra
$RUN_CMD ./05_test_qprop

gcc 06_test_rotor_refinement.c -o 06_test_rotor_refinement -lm -Wall -Wextra
$RUN_CMD ./06_test_rotor_refinement

#run binding test in python
if command -v python3 &> /dev/null; then
    python3 test_python_binding.py
else
    echo "Python not found, skipping test_python_binding.py"
fi

#run binding test in julia
if command -v julia &> /dev/null; then
    julia test_julia_binding.jl
else
    echo "Julia not found, skipping test_julia_binding.jl"
fi
