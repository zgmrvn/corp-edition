private _logic				= param [0, objNull, [objNull]];
private _units				= param [1, [], [[]]];
private _unitsFinal			= [];
private _triggers			= synchronizedObjects _logic;
private _areas				= [];
private _side				= side (_units select 0);
private _groupsPerArea		= _logic getVariable ["GroupsPerArea", 4];
private _unitsPerGroup		= _logic getVariable ["UnitsPerGroup", 4];
private _waypointsPerGroup	= _logic getVariable ["WaypointsPerGroup", 4];
private _dynamicSimulation	= _logic getVariable ["DynamicSimulation", true];
private _debug				= _logic getVariable ["Debug", false];

// todo : ajouter des sortie en cas d'erreur sur les paramètres

// pour chaque déclencheur synchronisé au module
{
	// on vérifie si la condition vaut true
	// si c'est le cas, c'est une zone définie par l'éditeur
	// on la pousse donc dans le tableau des zones
	if (((triggerStatements _x) select 0) == "true") then {
		_areas pushBack _x;
	};
} forEach _triggers;

// on défini la couleur des zones en fonction du side des IA synchronisées
private _areasColor = switch (_side) do {
	case west: {"ColorWEST"};
	case independent: {"ColorGUER"};
	default {"ColorEAST"};
};

// si le débug est demandé et que la machine a une interface
if (_debug && {hasInterface}) then {
	// on créé l'event handler responsable de dessiner les unités et les waypoints sur carte
	// cet event handler se base sur une variable globale qui sera chargé par chaque modules
	// seul le premier module a être activé exécutera ce code
	if (isNil {CORP_var_areaPatrols_patrols}) then {

		CORP_var_areaPatrols_patrols = [];

		// on déssine les zones et les unités sur carte
		((findDisplay 12) displayCtrl 51) ctrlAddEventHandler ["Draw", {
			private _map = _this select 0;

			// pour chaque groupe créé par un module Area Patrols et dont le paramètre "débug" est coché
			{
				private _group = _x;

				// on détermine la couleur du side du groupe
				private _sideColor = switch (side _group) do {
					case west: {[0, 0.3, 0.6, 1]};
					case independent: {[0, 0.5, 0, 1]};
					default {[0.5, 0, 0, 1]};
				};

				// on dessine chaque unité du groupe
				{
					_map drawIcon [
						getText (configFile >> "CfgVehicles" >> typeOf _x >> "Icon"),
						_sideColor,
						visiblePosition _x,
						0.5 / ctrlMapScale _map,
						0.5 / ctrlMapScale _map,
						getDirVisual _x
					];
				} forEach (units _group);

				private _waypointsCount = count (waypoints _group);

				// on dessine les waypoints du groupe
				for [{private _i = (_waypointsCount - 1)}, {_i > 0}, {_i = _i - 1}] do {
					_map drawLine [waypointPosition [_group, _i], waypointPosition [_group, _i - 1], _sideColor];
				};
				_map drawLine [waypointPosition [_group, 0], waypointPosition [_group, _waypointsCount - 1], _sideColor];
			} forEach CORP_var_areaPatrols_patrols;
		}];
	};

	// on dessine les zones sur carte
	{
		private _area = triggerArea _x;

		private _marker = createMarker [format ["area_%1", _x], _x];
		_marker setMarkerShape (["ELLIPSE", "RECTANGLE"] select (_area select 3));
		_marker setMarkerSize [_area select 0, _area select 1];
		_marker setMarkerDir (_area select 2);
		_marker setMarkerBrush "Border";
		_marker setMarkerColor _areasColor;
	} forEach _areas;
};

// pour chaque unité synchronisée au module
{
	private _unit = _x;

	// on récupères toutes les unités de son groupe
	// et on ajoute le classname de l'unité au tableau final d'unités s'il n'y est pas déjà
	{
		_typeOf = typeOf _x;
		if !(_typeOf in _unitsFinal) then {
			_unitsFinal pushBack _typeOf;
		};
	} forEach (units _unit);
} forEach _units;

// pour chaque zone on créé les patrouilles
{
	private _center	= getPosASL _x;
	private _area	= triggerArea _x;

	for "_i" from 0 to (_groupsPerArea - 1) do {
		private _unitsResized = [];
		private _random = ceil (random (_unitsPerGroup - 1));

		for "_ii" from 0 to _random do {
			_unitsResized pushBack (selectRandom _unitsFinal);
		};

		_patrol = [_center, _area, _side, _unitsResized, _waypointsPerGroup] call CORP_fnc_areaPatrols_createAreaPatrol;
		if (_debug) then {
			CORP_var_areaPatrols_patrols pushBack _patrol;
		};

		// activation/désactivation de la simulation dynamique pour le groupe créé
		_patrol enableDynamicSimulation _dynamicSimulation;
	};
} forEach _areas;

// todo : supprimer tous les triggers synchronisés

// on supprime manuellement le module
// on ne le fait pas via la propriété "disposable" de la config
// parce que le module est supprimé avant que l'on ait récupéré les déclencheurs synchronisés
deleteVehicle _logic;
