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

#Instruments
setprop("/systems/electrical/outputs/KNS80",28);
setprop("/systems/electrical/outputs/comm[0]",28);

#Rembrandt not supported
if(getprop("/sim/rendering/rembrandt/enabled")==1){
    printf("Rembrandt not supported! Use ALS.");
	gui.popupTip("Rembrandt is not supported. Please use ALS instead", 20);}

#Dialog
var clockDialogP = gui.Dialog.new("/sim/gui/dialogs/panel/clock0/dialog",
                        "Aircraft/c46/Dialogs/clockPilot.xml");
var clockDialogC = gui.Dialog.new("/sim/gui/dialogs/panel/clock1/dialog",
                        "Aircraft/c46/Dialogs/clockCopilot.xml");
						
_setlistener("/sim/time/warp", func(){
    if(getprop("instrumentation/clock[0]/dialog/real")==1){
		setprop("instrumentation/clock[0]/offset-sec", getprop("/sim/time/warp")*(-1));
	}
	if(getprop("instrumentation/clock[1]/dialog/real")==1){
		setprop("instrumentation/clock[1]/offset-sec", getprop("/sim/time/warp")*(-1));
	}
	
});