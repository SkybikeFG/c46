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
# Copilots AI Cageflag / Offflag
# offlag is on(1)  at  low spin(<1)  or  when cage-flag is on(1). 
# It works with listeners, Best for performance
#
# Step1: Wait for a property to change. If so, start a timer.
# Step2: "offlag_want" is 1-spin (eg. spin=0.8, flag=0.2)  or  1 if cage-flag is selected.
# Step3: add 0.01 (or -0.01) to the property until  "offflag_want" is reached. Then it stops the timer.
# See also: set.xml>instrumentation.xml (initialise flag properties) and models>cockpit>instruments>ai_2.xml
############################################

#var offflagb = props.globals.initNode("/instrumentation/attitude-indicator[1]/off-flag",1.0);


var ai_flag = func{
    var offflag = getprop("/instrumentation/attitude-indicator[1]/off-flag");
	
	var offflag_want=1-getprop("/instrumentation/attitude-indicator[1]/spin");
    if(getprop("/instrumentation/attitude-indicator[1]/caged-flag")==1){offflag_want=1;}
	
	#printf(""~offflag_want);
	if(offflag-offflag_want>=0.01){
	    setprop("/instrumentation/attitude-indicator[1]/off-flag", offflag-0.01);
		#printf("too small");
	}else{ 
	    if(offflag_want-offflag>=0.01){
	        setprop("/instrumentation/attitude-indicator[1]/off-flag", offflag+0.02);
			#printf("too large");
	    }else{aiflagtimer.stop();}#printf("reached value");}
	}
}

var aiflagtimer = maketimer(0.001, ai_flag);
setlistener("/instrumentation/attitude-indicator[1]/caged-flag", func(){aiflagtimer.start();},1,0);
setlistener("/systems/vacuummaster/suction-inhg", func(){aiflagtimer.start();},0,0);# "instr/ai[1]/spin" doesn't support listeners


	
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