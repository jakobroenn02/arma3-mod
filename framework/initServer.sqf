// initServer.sqf — [SERVER] authority bootstrap. See §G2.
call STCTI_fnc_initState;
call STCTI_fnc_initSectors;
call STCTI_fnc_loadCampaign;         // restore a saved campaign, if any (Phase 6) — before managers
call STCTI_fnc_startManagers;
call STCTI_fnc_startResolver;        // abstract combat resolver PFH (Phase 2)
call STCTI_fnc_startVirtualization;  // garrison proximity-caching PFH (Phase 2)
call STCTI_fnc_startProgression;     // unlock grants on capture (Phase 3)
call STCTI_fnc_directorTick;
call STCTI_fnc_startPersistence;     // autosave + save-on-capture (Phase 6)
call STCTI_fnc_startCivTraffic;      // ambient civilian cars near towns (Phase 8, §6.2)
call STCTI_fnc_startIntel;           // enemy-garrison scans from held military sites (Phase 12)

// The base garage is NOT spawned here — it's established where the player picks their
// starting zone at campaign start (STCTI_fnc_serverPlaceBase).
