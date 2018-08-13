aircraft.livery.init("Aircraft/c46/Models/Liveries"); 

beacon_switch = props.globals.getNode("controls/switches/beacon", 1);
var beacon = aircraft.light.new( "/sim/model/lights/beacon", [0.05, 0.8,], "/controls/lighting/beacon" );

#OILCOOLER
var oilcoolerl = props.globals.initNode("/controls/engines/engine[0]/oilcooler",0,"BOOL");#Left Oilcooler
var oilcoolerr = props.globals.initNode("/controls/engines/engine[1]/oilcooler",0,"BOOL");#Right Oilcooler

#Armrests
var armrestc = props.globals.initNode("/controls/seat/armrest-copilot",0,"BOOL");
var armrestp = props.globals.initNode("/controls/seat/armrest-copilot",0,"BOOL");

#Fuel pressure, needs more work
setprop("/engines/engine[0]/fuel-psi-norm",18);
setprop("/engines/engine[1]/fuel-psi-norm",18);