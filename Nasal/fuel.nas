# nasal fuel system support - for c46 - by Skybike (Arnd Lebert) 
# in combination with xml-based fuel system by snowblind1  
# 2018 - GNU GPL v2+
########
# set theoretical fuel pressure of every tank pump
# set fuel pressure of every engine (using the above)
# handle fuel boost pumps (off/low/high)
###
# handle crossfeed (based on pressure)
# write "/controls/fuel/left-feed"
###
# Use boxes in "fuel- and Payload" dialog as fuel selector:
# - When valve changes-> change selection boxes 
# - when box changes -> deactivate the previously selected box and change valves
########

props.globals.initNode("/controls/fuel/crossfeed", 0, "BOOL");
props.globals.initNode("/controls/fuel/left-feed", getprop("/controls/fuel/left-valve"), "INT");
props.globals.initNode("/controls/fuel/right-feed", getprop("/controls/fuel/right-valve"), "INT");
props.globals.initNode("/consumables/fuel/tank[10]/pressure-pump-psi", 0, "INT");

var fuelpressTank = func(tank){
	var levelGalUS = getprop("/consumables/fuel/tank["~tank~"]/level-gal_us");
	var levelNorm = getprop("/consumables/fuel/tank["~tank~"]/level-norm");
	#var pressurePsi = getprop("/environment/pressure-psi");
	#var airTemp = getprop("/environment/temperature-degc");
	
	var press = 17;
	
	#Tank 100% to 50% -> full pressure
	if( levelNorm < 0.5 ){
		press -= 2*(0.5-levelNorm) * 2 ;#linear: tank 50% (-0psi) to 0% (- 2*1psi)
		
		if( levelGalUS < 20){#Overheating of sump pump when less than 20gal:
			press = press - (10-levelGalUS/2);#linear 20gal (-0psi) to 0gal (-10psi)
			
			if(levelGalUS ==0){#empty, no pressure
				press = 0;
			}
		}
	}
	# Add new calculations here:
	
	setprop("/consumables/fuel/tank["~tank~"]/pressure-pump-psi", press);
}


fuelpressEngine = func(){
	#Todo: Sump Pumps need some seconds to run, produce full pressure and fill the whole fuel line (feeders) Idea: interpolate()
	setprop("/engines/engine[0]/fuel-psi-norm", getprop("/consumables/fuel/tank["~getprop("/controls/fuel/left-feed")~"]/pressure-pump-psi"));
	setprop("/engines/engine[1]/fuel-psi-norm", getprop("/consumables/fuel/tank["~getprop("/controls/fuel/right-feed")~"]/pressure-pump-psi"));
}

#####
# crossfeed control based on fuel pressure
# write left-feed and right-feed
# prepared to add auxilary tank
# needs listeners above
# Note: change in fuel.xml every "left-valve" to the new "left-feed" to activate it.
#       the crossfeed switch is at "/controls/fuel/crossfeed"
#####

var selectTank = func(){
	if(getprop("/controls/fuel/crossfeed") == 0){#No crossfeed
		var leftValve = getprop("/controls/fuel/left-valve");
		var rightValve = getprop("/controls/fuel/right-valve");
		if(leftValve<0){# off position
			leftValve=10}
		if(rightValve<0){# off position
			rightValve=10}
		setprop("/controls/fuel/left-feed", leftValve);
		setprop("/controls/fuel/right-feed", rightValve);
		
	}else{#crossfeed
	
		var leftValve=getprop("/controls/fuel/left-valve");
		var rightValve=getprop("/controls/fuel/right-valve");
		
		var leftPress=0.0;
		var rightPress=0.0;
		if(leftValve>=0){#if selected Tank is OFF (-1), the pressure stays 0
			leftPress=getprop("/consumables/fuel/tank["~leftValve~"]/pressure-pump-psi");}
		if(rightValve>=0){
			rightPress=getprop("/consumables/fuel/tank["~rightValve~"]/pressure-pump-psi");}
		
		var differencePress=rightPress-leftPress;
		#above differencePress becomes positiv when right pressure is higher->crossfeed flow from right to left (and vise versa)
		
		if(differencePress>0.2){# all feed right
			setprop("/controls/fuel/left-feed", rightValve);
			setprop("/controls/fuel/right-feed", rightValve);
		}else{ 
			if(differencePress<-0.2){# all feed left
				setprop("/controls/fuel/left-feed", leftValve);
				setprop("/controls/fuel/right-feed", leftValve);
			}else{#difference is too small (+-0.2 psi)
				setprop("/controls/fuel/left-feed", leftValve);
				setprop("/controls/fuel/right-feed", rightValve);
			}
		}
		
		#var auxTankPress=getprop("/consumables/fuel/tank[8]/pressure-pump-psi");
		#if(auxTankPress>rightValve && auxTankPress>leftValve){
		#	setprop("/controls/fuel/left-feed", 8);
		#	setprop("/controls/fuel/right-feed", 8);
		#}
	}
}
	
var fuelpressFeeder = func(){
}


#####
# Use boxes in "Fuel and Payload" dialog as fuel selector
# - When valve changes-> change selection boxes 
# - when box changes -> deactivate the previously selected box and change valves
# It is not possible to selet the OFF position with boxes
#####

#init some Nodes/Properties/variables
for(var i=0; i<6; i+=1){
	props.globals.initNode("/consumables/fuel/tank["~i~"]/selected", 1, "BOOL");}
	
var leftReference = getprop("/controls/fuel/left-valve");
var rightReference = getprop("/controls/fuel/right-valve");

time=getprop("/sim/time/mp-clock-sec");# The reference time of the frame. Deactivate listener loops/overflows.
	
#update Boxes
var fuelPayloadValve = func(){	
	time=getprop("/sim/time/mp-clock-sec");
	for(var i=0; i<6; i+=1){
		var active = getprop("/consumables/fuel/tank["~i~"]/selected");
		
		if(rightReference != i and leftReference != i and active==1){#Deactivate Boxes
			settimer(fuelPayloadValve, 0.2, 1);# it seems that you can't change more than one box per frame
			setprop("/consumables/fuel/tank["~i~"]/selected", "false");
		}
		if((rightReference == i or leftReference == i) and active==0){#Activate Boxes
			setprop("/consumables/fuel/tank["~i~"]/selected", 1);
		}
	}
}
		
#Set listeners for Valves
setlistener("/controls/fuel/left-valve", func(){ 
	if (getprop("/sim/time/mp-clock-sec") != time){#otherwise a listener would call the next listener
		time=getprop("/sim/time/mp-clock-sec");#     - only one listener per frame (time)
		if(leftReference !=getprop("/controls/fuel/left-valve")){
			leftReference = getprop("/controls/fuel/left-valve");
			fuelPayloadValve();
		}
	}
},0,0);
setlistener("/controls/fuel/right-valve", func(){
	if (getprop("/sim/time/mp-clock-sec") != time){
		time=getprop("/sim/time/mp-clock-sec");
		if(rightReference !=getprop("/controls/fuel/right-valve")){
			rightReference = getprop("/controls/fuel/right-valve");
			fuelPayloadValve();
		}
	}
},0,0);

#set listeners for boxes
var listenerfunc = func(i){
	if(getprop("/sim/time/mp-clock-sec") != time){
		time=getprop("/sim/time/mp-clock-sec");
		if(i == 0 or i == 2 or i == 4){	
			if(getprop("/consumables/fuel/tank["~i~"]/selected") == 1 and leftReference != i){
				leftReference = i;
				setprop("/controls/fuel/left-valve", i);
			}
		}else{
			if(getprop("/consumables/fuel/tank["~i~"]/selected") == 1 and rightReference != i){
				rightReference = i;
				setprop("/controls/fuel/right-valve", i);
			}
		}
		fuelPayloadValve();
	}
}

setlistener("/consumables/fuel/tank[3]/selected", func(){ listenerfunc(3);},0,0);
setlistener("/consumables/fuel/tank[4]/selected", func(){ listenerfunc(4);},0,0);
setlistener("/consumables/fuel/tank[5]/selected", func(){ listenerfunc(5);},0,0);
setlistener("/consumables/fuel/tank[2]/selected", func(){ listenerfunc(2);},0,0);
setlistener("/consumables/fuel/tank[1]/selected", func(){ listenerfunc(1);},0,0);
setlistener("/consumables/fuel/tank[0]/selected", func(){ listenerfunc(0);},0,0);

#first Run
fuelPayloadValve();


#####
# Timers and loops for crossfeed and pressure (not valves, see listeners above)
#####

#Fuel Pressure Timer
var fullRun = func(){
	#Fuel Pressure Taks
	for(var i=0; i<5; i+=1){
		fuelpressTank(i);
	}
	#Fuel Pressure Engines
	fuelpressEngine();
}

var fuelTimer = maketimer(0.5, func{fullRun();} );
_setlistener("/sim/signals/fdm-initialized", func(){ fuelTimer.start(); });

# Select Tanks and crossfeed
var crossfeedTimer = maketimer(0.5, func{selectTank();} ); # when crossfeed activated, it changes based on pressure, timer needed.  

setlistener("/controls/fuel/crossfeed", func(){
		if(getprop("/controls/fuel/crossfeed")==1){	
			crossfeedTimer.start();
			gui.popupTip("Activated crossfeed", 5);
		}else{crossfeedTimer.stop();
			gui.popupTip("Deactivated crossfeed", 5);
			selectTank();}
	},0,0);
	#if not it changes when valves change
setlistener("/controls/fuel/left-valve", func(){ selectTank(); });
setlistener("/controls/fuel/right-valve", func(){ selectTank(); });
_setlistener("/sim/signals/fdm-initialized", func(){ selectTank(); });#initial start
	
	
printf("C46 nasal fuel system initialized");