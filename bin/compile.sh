#!/bin/bash

zig cc ../qprop.c -o ./qprop/qprop-lib-windows-x64.dll -shared -target x86_64-windows-gnu -lm -fPIC -O2 -Wall -Wextra
zig cc ../qprop.c -o ./qprop/qprop-lib-linux-x64.so -shared -target x86_64-linux-gnu -lm -fPIC -O2 -Wall -Wextra
zig cc ../qprop.c -o ./qprop/qprop-lib-macos-arm64.dylib -shared -target aarch64-macos -lm -fPIC -O2 -Wall -Wextra

rm ./qprop/qprop.lib
rm ./qprop/qprop-lib-windows-x64.pdb

