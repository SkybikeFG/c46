##############################################
# General systems nasal file for C-46.       #
# C-46 by Arnd Lebert, John Gilbert          #
# 2018 - GNU GPL v2+                         #
##############################################

##############################################
# Vacuum system - Take highest pump output   #
# value. Real life system is set to use both #
# or either engine pump outputs across both  #
# sides of the cockpit instruments. Drives   #
# ADIs (artificial horizons) and Heading     #
# indicators.                                #
##############################################


setprop("systems/vacuummaster/suction-inhg", 0);

var vacuum_inhg = func {
	var pump1 = getprop("systems/vacuum/suction-inhg");
	var pump2 = getprop("systems/vacuum[1]/suction-inhg");
	var m = math.max(pump1, pump2);
    setprop("/systems/vacuummaster/suction-inhg",m);	
	};

var vacuumtimer = maketimer(1, vacuum_inhg);
vacuumtimer.start();
	

printf("C46 nasal general systems initialized");