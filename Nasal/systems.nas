##############################################
# General systems nasal file for C-46.       #
# C-46 by Arnd Lebert, John Gilbert          #
# 2018 - GNU GPL v2+                         #
##############################################

##############################################
# Vacuum system - average both pumps for one #
# output. Real life system is set to use both#
# or either engine pump outputs across both  #
# sides of the cockpit instruments. Drives   #
# ADIs (artificial horizons) and Heading     #
# indicators.                                #
##############################################

props.globals.initNode("/systems/vacuummaster/suction-inhg", 0, "DOUBLE");

var vacuum_inhg = func() 
	{
	var pump1 = getProp("/systems/vacuum/suction-inhg");
	var pump2 = getProp("/systems/vacuum[1]/suction-inhg");
	var serviceable1 = getProp("/systems/vacuum/serviceable");
	var serviceable2 = getProp("/systems/vacuum[1]/serviceable");
		
	if (((pump1 > 0) and (serviceable1 > 0)) and ((pump2 > 0) and (serviceable2 > 0))) # Normal operations
	{ setprop("/systems/vacuummaster/suction-inhg", (pump1 + pump 2)/2); }
	
	if ((pump1 > 0) and (serviceable1 > 0)) and ((pump2 < 3) or (serviceable2 < 1))) # Left engine only operating
	{ setprop("/systems/vacuummaster/suction-inhg", pump1); }
	
	if ((pump2 > 0) and (serviceable2 > 0)) and ((pump1 < 3) or (serviceable1 < 1))) # Right engine only operating
	{ setprop("/systems/vacuummaster/suction-inhg", pump2);	}
	
	settimer(vacuum_inhg, 0.5)
	}
	
	setlistener("sim/signals/fdm-initialized", vaccum_inhg)
	
	
	
	printf("C46 nasal general systems initialized");