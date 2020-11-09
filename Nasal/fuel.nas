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
props.globals.initNode("/consumables/fuel/tank[99]/pressure-pump-psi", 0, "INT");#Off position tank[99], as getprop(".../tank[-1]/...") trows an error

var fuelpressTank = func(tank){
	var levelGalUS = getprop("/consumables/fuel/tank["~tank~"]/level-gal_us");
	var levelNorm = getprop("/consumables/fuel/tank["~tank~"]/level-norm");
	#var pressurePsi = getprop("/environment/pressure-psi");
	#var airTemp = getprop("/environment/temperature-degc");
	
	var press = 16.5;
		
	
	#Tank 100% to 50% -> full pressure
	if( levelNorm < 0.5 ){
		press -= 2*(0.5-levelNorm) * 2 ;#linear: tank 50% (-0psi) to 0% (- 2*1psi)
		
		if( levelGalUS < 20){#Overheating of sump pump when less than 20gal:
			press = press - (10-levelGalUS/2);#linear 20gal (-0psi) to 0gal (-10psi)
		}
	}
	
	if(tank == getprop("/controls/fuel/left-valve") and getprop("/controls/fuel/boostpumps-l-high")==1){
		press = press + 2;}#boostpumps==1
	if(tank == getprop("/controls/fuel/right-valve") and getprop("/controls/fuel/boostpumps-r-high")==1){
		press = press + 2;}
		
	if(levelGalUS ==0){#empty, no pressure
		press = 0;}
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
			leftValve=99}
		if(rightValve<0){# off position
			rightValve=99}
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
# Define fuel selector position and limit its rotation speed
#####
# define "timer" variable (although the callback does not exist yet, so we use another one)
var fuelpositionTimer = maketimer(0.1, func{listenerfunc();} );

var rotatevalve = func(){
    var jobDone = 1;#end timer
    # current animation position (0.0 ... 3.9)
    var rValvePos = getprop("/controls/fuel/right-valve-pos");
    var lValvePos = getprop("/controls/fuel/left-valve-pos");
    
    # wanted value (make -2...4 to 0...3) 
    var valvePattern = [0.0, 0.0, 1.0, 1.0, 2.0, 2.0, 3.0, 3.0];
    var rGoal = valvePattern[ getprop("/controls/fuel/right-valve")+2 ];
    var lGoal = valvePattern[ getprop("/controls/fuel/left-valve")+2 ];
    
    #end of ring scale
    if(rGoal==3 and rValvePos < 1){
        rValvePos=rValvePos+4;
    }
    if(rGoal==0 and rValvePos > 2){
        rValvePos=rValvePos-4;
    }
    if(lGoal==3 and lValvePos < 1){
        lValvePos=lValvePos+4;
    }
    if(lGoal==0 and lValvePos > 2){
        lValvePos=lValvePos-4;
    }
    
    # right value rising or falling? then let valve slowly rise or fall as well
    if(rValvePos < rGoal-0.03){
        # "< Goal-0.03" to prevent it from oszillating 0.99 1.04 0.99 1.04 forever
        setprop("/controls/fuel/right-valve-pos", rValvePos + 0.05);
        jobDone = 0;
    }else if(rValvePos > rGoal+0.03){
        setprop("/controls/fuel/right-valve-pos", rValvePos - 0.05);
        jobDone = 0;
    }
    if(lValvePos < lGoal-0.03){
        setprop("/controls/fuel/left-valve-pos", lValvePos + 0.05);
        jobDone = 0;
    }else if(lValvePos > lGoal+0.03){
        setprop("/controls/fuel/left-valve-pos", lValvePos - 0.05);
        jobDone = 0;
    }
    
    # stop timer
    if(jobDone==1){
        fuelpositionTimer.stop();
    }
}

# now the callback for our timer exists, here we go to redefine it.
fuelpositionTimer = maketimer(0.05, func{rotatevalve();} );
fuelpositionTimer.start();#start during fg startup

#####
# Autofuel - Let autofuel change the tank (like a copilot)
#####
var autofuelLoop = func(){
    var selectLeft = getprop("/controls/fuel/left-valve");
	var selectRight = getprop("/controls/fuel/right-valve");
    if(getprop("/consumables/fuel/tank["~ selectLeft ~"]/level-gal_us") < 20.0){
	    if(selectLeft == 4){
		    selectLeft = 0;
		}else{
		    selectLeft += 2;
		}
		setprop("/controls/fuel/left-valve", selectLeft);
	}
	if( getprop("/consumables/fuel/tank["~ selectRight ~"]/level-gal_us") < 20){
	    if( selectRight == 5){
		    selectRight = 1;
		}else{
		    selectRight += 2;
		}
		setprop("/controls/fuel/right-valve", selectRight );
		gui.popupTip("Copilot changed tank selection", 4);
	}
}
	
props.globals.initNode("/controls/autoflight/autofuel", 0, "BOOL");

var autofuel = maketimer(5, func{autofuelLoop();} );
		
_setlistener("/controls/autoflight/autofuel", func(){
    if(getprop("/controls/autoflight/autofuel")==1){
		autofuel.start();
	}else{
	    if(autofuel.isRunning){autofuel.stop();}
	}
});

#####
# Timers and loops for crossfeed and pressure (not valves, see listeners above)
#####

#Fuel Pressure Timer
var fullRun = func(){
	#Fuel Pressure Taks
	for(var i=0; i<6; i+=1){
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
setlistener("/controls/fuel/left-valve", func(){ selectTank(); fuelpositionTimer.start();});
setlistener("/controls/fuel/right-valve", func(){ selectTank(); fuelpositionTimer.start();});
_setlistener("/sim/signals/fdm-initialized", func(){ selectTank(); });#initial start
	
	
printf("C46 nasal fuel system initialized");