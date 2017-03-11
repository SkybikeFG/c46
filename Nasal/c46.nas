aircraft.livery.init("Aircraft/c46/Models/Liveries"); 

beacon_switch = props.globals.getNode("controls/switches/beacon", 1);
var beacon = aircraft.light.new( "/sim/model/lights/beacon", [0.05, 0.8,], "/controls/lighting/beacon" );
