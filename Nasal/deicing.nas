# nasal anti-ice system for c46 by Skybike (Arnd Lebert) 
# 2018  GNU GPL v2+
######
# calculate carburetor air temperature
# listen to carburetor heater switch
#####
# Carburetor switch is a bool at /controls/anti-ice/engine[0]/carb-heat 
# Carburetor temperature in degc is at /engines/engine[0]/carbtemp-degc
# Register in -set.xml <nasal>
#####
# Pilots instructions:
# Engine has to run. Push carburetor lever when carburetor air temperature is below 15 degC, deactivate when at 40 degC
#####


var carbtemp = func(){
    var airTemp = getprop("/environment/temperature-degc");
    var tempCarbL = ( getprop("/engines/engine[0]/cht-degf") - 32) * 5/9;
	var tempCarbR = ( getprop("/engines/engine[1]/cht-degf") - 32) * 5/9;
	
	#CylHeadTemp can go up to 250degC, lets say the carb becomes about 10deg warmer than outside.
	tempCarbL = airTemp + (tempCarbL - airTemp) / 25;
	tempCarbR = airTemp + (tempCarbR - airTemp) / 25;
    
    #"Carburetor Heater" is a door that takes the air next to the exhaust. egt(ExhaustGasTemp) has to be > 90F to heat.
    #Normally you have to mix the right temperature manually, here its done automatically.
    if(getprop("/controls/anti-ice/engine[0]/carb-heat") == 1 and getprop("/engines/engine[0]/egt-degf") > 90 ){
        if(tempCarbL < 5){tempCarbL = 20;} else {tempCarbL += 15;} }
	if(getprop("/controls/anti-ice/engine[1]/carb-heat") == 1 and getprop("/engines/engine[1]/egt-degf") > 90 ){
        if(tempCarbR < 5){tempCarbR = 20;} else {tempCarbR += 15;} }
	  
    #slowly increasing  
    tempCarbL = tempCarbL + ( (getprop("/engines/engine[0]/carbtemp-degc") - tempCarbL) / 5);
    tempCarbR = tempCarbR + ( (getprop("/engines/engine[1]/carbtemp-degc") - tempCarbR) / 5);
    setprop("/engines/engine[0]/carbtemp-degc", tempCarbL);
	setprop("/engines/engine[1]/carbtemp-degc", tempCarbR);
}

var carbTimer = maketimer(2, func{carbtemp();} );
_setlistener("/sim/signals/fdm-initialized", func(){ carbTimer.start(); });

#initialise
setprop("/engines/engine[0]/carbtemp-degc", 20);
setprop("/engines/engine[1]/carbtemp-degc", 20);
printf("C46 deicing system initialized");
