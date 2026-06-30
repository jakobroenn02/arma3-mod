// fn_countSpawnedUnits.sqf — [SERVER] no params -> Number
// How many live framework-spawned AI exist right now (every unit fn_spawnForce makes is tagged
// with STCTI_type). This is the budget meter: it counts actual living units, so combat losses
// free budget automatically, and it never double-counts an adopted garrison.
if (!isServer) exitWith { 0 };
count (allUnits select { (_x getVariable ["STCTI_type", ""]) != "" })
