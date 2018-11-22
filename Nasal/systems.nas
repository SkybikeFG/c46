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
	
	
	
############################################
# Electrical helper system
# stores some functions to test lightning...
# this system should get
# integrated into the electrical system, 
# once there is sth. like a overhead panel
# and a stable electrical support
############################################

# Annunciator dimmer switch (with test): 
# - bool on (click) > light test > all lights on > new value (bright/dimm)
# - bool of (release click) > test signal lights 3 more sec > then 
#    slowly off (here linear like condensator || ptc lamps)
# Animation calls "c46.annunciator_switch;" and "c46.annuntimer.start();"

var annun_condensator = 0.0;
var annun_norm = 1.0;

var annunciator_switch = func {   
	if(annun_condensator < 1.8){
	    if(annun_norm < 1.0)#bright
		{
		    annun_norm = 1.0;
		}else{#dimm
		    annun_norm = 0.5;#change dimm value here
		}
		
		setprop("controls/lighting/annun-on-norm", annun_norm);
		setprop("controls/lighting/annun-off-norm", annun_norm);
		setprop("instrumentation/kma20/test", annun_norm);
	} 
	annun_condensator = 2.0;#load
    
};

var annun_unload = func{
    annun_condensator = annun_condensator-0.03;#change unload time here (higher means faster)
	
	if(annun_condensator>1.70){
        if(annun_condensator<1.8){#switch animation position (-1, 0, 1)
	        if(annun_norm==1){
	           setprop("controls/lighting/annun-switch", 1);
		    }else{
		       setprop("controls/lighting/annun-switch", -1);
		    }
	}   }
	
	if(annun_condensator<1.0){
	    setprop("controls/lighting/annun-off-norm", annun_condensator*annun_norm);
		setprop("instrumentation/kma20/test", annun_condensator*annun_norm);
	}
		
	if(annun_condensator<=0)#empty
	    annuntimer.stop();
}
    
var annuntimer = maketimer(0.05, annun_unload);
	

printf("C46 nasal general systems initialized");