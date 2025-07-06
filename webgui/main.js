//------------------------------------------------------------------------------
//  A simple propeller calculator built on top of qprop.c using WASM.
//  This module implements user input logic and communication with
//  the WASM module.
//
//  Author: Andrea Pavan
//  License: MIT
//------------------------------------------------------------------------------


//load WASM functions
const initialize_geometry = Module.cwrap("initialize_geometry", "void", ["number", "number"]);
const add_geometry_section = Module.cwrap("add_geometry_section", "void", ["number", "number", "number", "number"]);
const run_analysis = Module.cwrap("run_analysis", "void", ["number", "number", "number", "number", "number"]);

//add row to the geometry table
document.addEventListener("click", function(event) {
    if (event.target.classList.contains("add-row")) {
        var currentRow = event.target.parentNode.parentNode.parentNode;
        var newRow = document.createElement("tr");
        newRow.innerHTML = `
            <td></td>
            <td><input type="text" value="0.0"></td>
            <td><input type="text" value="0.0"></td>
            <td><input type="text" value="0.0"></td>
            <td>
                <div class="add-remove-buttons">
                    <button type="button" class="add-row">+</button>
                    <button type="button" class="remove-row">-</button>
                </div>
            </td>
        `;
        currentRow.parentNode.insertBefore(newRow, currentRow.nextSibling);
    }
});

//remove row from the geometry table
document.addEventListener("click", function(event) {
    if (event.target.classList.contains("remove-row")) {
        var currentRow = event.target.parentNode.parentNode.parentNode;
        currentRow.parentNode.removeChild(currentRow);
    }
});

//run button click event
document.getElementById("run-button").addEventListener("click", function() {
    //get input values
    const D = 0.001 * parseFloat(document.getElementById("diameter").value);
    const B = parseInt(document.getElementById("num-blades").value);
    const Omega = (Math.PI/30) * parseFloat(document.getElementById("rotor-speed").value);
    const Uinf = parseFloat(document.getElementById("airspeed").value);
    const airfoilIdx = parseInt(document.getElementById("airfoil").selectedIndex);
    const rho = parseFloat(document.getElementById("air-density").value);
    const mu = parseFloat(document.getElementById("air-dynamic-viscosity").value);
    const Npanels = parseInt(document.getElementById("refine-panels").value);

    //perform analysis
    initialize_geometry(D, B);
    const Nsections = document.getElementById("geometry-table-body").rows.length;
    for (let i=0; i<Nsections; i++) {
        //call add_geometry_section for each row in the table
        const cells = document.getElementById("geometry-table-body").rows[i].getElementsByTagName("td");
        const r = 0.001 * parseFloat(cells[1].querySelector("input").value);
        const c = 0.001 * parseFloat(cells[2].querySelector("input").value);
        const beta = (Math.PI/180) * parseFloat(cells[3].querySelector("input").value);
        add_geometry_section(c, beta, r, airfoilIdx);
    }
    run_analysis(Omega, Uinf, rho, mu, Npanels);

    //show results
    document.getElementById("results-container").style.display = "block";
    document.getElementById("results-container").scrollIntoView({ behavior: "smooth"});
});

