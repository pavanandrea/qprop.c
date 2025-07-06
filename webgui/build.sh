#!/bin/bash
emcc qprop_web_interface.c -o qprop_web_interface.js -O2 -s EXPORTED_FUNCTIONS='["_initialize_geometry", "_add_geometry_section", "_run_analysis", "_main"]' -s WASM=1 -s EXPORTED_RUNTIME_METHODS='["ccall", "cwrap", "UTF8ToString"]' -s FORCE_FILESYSTEM=1 --preload-file airfoil_polars

#run
python3 -m http.server 8080 &
firefox -private-window http://0.0.0.0:8080/index.html

