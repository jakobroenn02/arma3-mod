// fn_wipeSave.sqf — [SERVER] no params. Deletes this map's campaign save; the next mission
// start is a fresh campaign. Run from the debug console: `call STCTI_fnc_wipeSave`.
if (!isServer) exitWith {};
profileNamespace setVariable [format ["STCTI_save_%1", worldName], nil];
saveProfileNamespace;
diag_log format ["[STCTI] Campaign save for %1 wiped.", worldName];
systemChat "STCTI: campaign save wiped — restart the mission for a new campaign.";
