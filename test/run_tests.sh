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

#compile all C files in the current directory
C_FILES=*.c
for cfile in $C_FILES; do
    #compile
    filename="${cfile%.c}"
    echo ""
    echo "--- TEST ${filename} ---"
    echo ""
    gcc "$cfile" -o "${filename}" -lm -Wall -Wextra
    if [ $? -ne 0 ]; then
        echo "Compilation of ${cfile} failed."
        exit 1
    fi

    #run test and remove executable
    ${RUN_CMD} ./${filename}
    if [ $? -ne 0 ]; then
        echo "Test ${filename} failed."
        exit 1
    fi
    rm -f "${filename}"
done

#run binding test in python
if command -v python3 &> /dev/null; then
    echo ""
    echo "--- TEST PYTHON BINDING ---"
    echo ""
    python3 test_python_binding.py
else
    echo "Python not installed, skipping test_python_binding.py"
fi

#run binding test in julia
if command -v julia &> /dev/null; then
    echo ""
    echo "--- TEST JULIA BINDING ---"
    echo ""
    julia test_julia_binding.jl
else
    echo "Julia not installed, skipping test_julia_binding.jl"
fi
