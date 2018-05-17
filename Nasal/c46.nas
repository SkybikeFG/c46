aircraft.livery.init("Aircraft/c46/Models/Liveries"); 

beacon_switch = props.globals.getNode("controls/switches/beacon", 1);
var beacon = aircraft.light.new( "/sim/model/lights/beacon", [0.05, 0.8,], "/controls/lighting/beacon" );

#OILCOOLER
var oilcoolerl = props.globals.initNode("/controls/engines/engine[0]/oilcooler",0,"BOOL");#Left Oilcooler
var oilcoolerr = props.globals.initNode("/controls/engines/engine[1]/oilcooler",0,"BOOL");#Right Oilcooler

ki266.new(0); # for your first dme at /instrumentation/dme[0]
#ki266.new(1); # if you have another at /instrumentation/dme[1]