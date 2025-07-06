#!/bin/bash

zig cc ../src/qprop.c -o ./qprop-portable/qprop-lib-windows-x64.dll -shared -target x86_64-windows-gnu -lm -fPIC -O2 -Wall -Wextra
zig cc ../src/qprop.c -o ./qprop-portable/qprop-lib-linux-x64.so -shared -target x86_64-linux-gnu -lm -fPIC -O2 -Wall -Wextra
zig cc ../src/qprop.c -o ./qprop-portable/qprop-lib-macos-arm64.dylib -shared -target aarch64-macos -lm -fPIC -O2 -Wall -Wextra

rm ./qprop-portable/qprop.lib
rm ./qprop-portable/qprop-lib-windows-x64.pdb

cp ../src/qprop.h ./qprop-portable/qprop.h
cp ../src/bindings/qprop.jl ./qprop-portable/qprop.jl
cp ../src/bindings/qprop.py ./qprop-portable/qprop.py
cp ../LICENSE ./qprop-portable/LICENSE
