// initServer.sqf — [SERVER] authority bootstrap. See §G2.
call STCTI_fnc_initState;
call STCTI_fnc_initSectors;
call STCTI_fnc_startManagers;
call STCTI_fnc_directorTick;

// Spawn the base garage object (slice: a single hardcoded station) and publish it
// so clients can attach their purchase actions to it.
STCTI_garage = createVehicle ["Land_Cargo_HQ_V1_F", STCTI_BASE_POS, [], 0, "NONE"];
STCTI_garage setVariable ["STCTI_isGarage", true, true];
publicVariable "STCTI_garage";
