#!/bin/bash

gcc 01_test_fzero.c -o 01_test_fzero -lm -Wall -Wextra
./01_test_fzero

gcc 02_test_import_xfoil_polars.c -o 02_test_import_xfoil_polars -lm -Wall -Wextra
./02_test_import_xfoil_polars

gcc 03_test_interpolate_airfoil_polars.c -o 03_test_interpolate_airfoil_polars -lm -Wall -Wextra
./03_test_interpolate_airfoil_polars

gcc 04_test_residual.c -o 04_test_residual -lm -Wall -Wextra
./04_test_residual

gcc 05_test_qprop.c -o 05_test_qprop -lm -Wall -Wextra
./05_test_qprop

gcc 06_test_rotor_refinement.c -o 06_test_rotor_refinement -lm -Wall -Wextra
./06_test_rotor_refinement

if command -v python3 &> /dev/null; then
    #echo "Python binding test:"
    python3 test_python_binding.py
else
    echo "Python not found, skipping test_python_binding.py"
fi

if command -v julia &> /dev/null; then
    #echo "Julia binding test:"
    julia test_julia_binding.jl
else
    echo "Julia not found, skipping test_julia_binding.jl"
fi
