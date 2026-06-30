// initServer.sqf — [SERVER] authority bootstrap. See §G2.
call STCTI_fnc_initState;
call STCTI_fnc_initSectors;
call STCTI_fnc_startManagers;
call STCTI_fnc_startResolver;   // abstract combat resolver PFH (Phase 2)
call STCTI_fnc_directorTick;

// The base garage is NOT spawned here — it's established where the player picks their
// starting zone at campaign start (STCTI_fnc_serverPlaceBase).
