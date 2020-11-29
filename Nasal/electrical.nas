# nasal electrical system for c46 by Snowblind1 (John Gilbert) 
# 2018  GNU GPL v2+
######
# Adjustments by Skybike (Arnd Lebert) 2020 during second lockdown
######
# Procedural model of a C46 Commando electrical system.  Includes a
# preliminary battery charge/discharge model and realistic ammeter
# gauge modeling.
# 
# Basic code was borrowed from the C172P.


##
# Initialize internal values
#

var vbus_volts = 0.0;
var ebus1_volts = 0.0;
var ebus2_volts = 0.0;

var ammeter_ave = 0.0;

##
# Battery model class.
#
# C46 has 24 volt system with two 200 amp batteries

var BatteryClass = {};

BatteryClass.new = func(num){
    var obj = { parents : [BatteryClass],
                charge_prop : "/systems/electrical/battery[" ~ num ~ "]/charge-percent",
                ideal_volts : 24.0,
                ideal_amps : 200.0,
                amp_hours : 36,
                charge_percent : getprop("/systems/electrical/battery[" ~ num ~ "]/charge-percent") or 1.0,
                charge_amps : 50.0 }; # COMPLETE WAG HERE!!!
    setprop(obj.charge_prop, obj.charge_percent);
    return obj;
}

##
# Passing in positive amps means the battery will be discharged.
# Negative amps indicates a battery charge.
#

BatteryClass.apply_load = func (amps, dt) {
    var old_charge_percent = getprop(me.charge_prop);

    if (getprop("/sim/freeze/replay-state"))
        return me.amp_hours * old_charge_percent;

    var amphrs_used = amps * dt / 3600.0;
    var percent_used = amphrs_used / me.amp_hours;

    var new_charge_percent = std.max(0.0, std.min(old_charge_percent - percent_used, 1.0));

    if (new_charge_percent < 0.1 and old_charge_percent >= 0.1)
        gui.popupTip("Warning: Low battery! Enable Generator or apply external power to recharge battery!", 10);
    me.charge_percent = new_charge_percent;
    setprop(me.charge_prop, new_charge_percent);
    return me.amp_hours * new_charge_percent;
}

##
# Return output volts based on percent charged.  Currently based on a simple
# polynomial percent charge vs. volts function.
#

BatteryClass.get_output_volts = func {
    var x = 1.0 - me.charge_percent;
    var tmp = -(3.0 * x - 1.0);
    var factor = (tmp*tmp*tmp*tmp*tmp + 32) / 32;
    return me.ideal_volts * factor;
}


##
# Return output amps available.  This function is totally wrong and should be
# fixed at some point with a more sensible function based on charge percent.
# There is probably some physical limits to the number of instantaneous amps
# a battery can produce (cold cranking amps?)
#

BatteryClass.get_output_amps = func {
    var x = 1.0 - me.charge_percent;
    var tmp = -(3.0 * x - 1.0);
    var factor = (tmp*tmp*tmp*tmp*tmp + 32) / 32;
    return me.ideal_amps * factor;
}

##
# Charge the battery with maximum and return remaining amps
#

BatteryClass.charge_get_remaining = func (amps, voltage, dt){
    if(voltage>me.get_output_volts()){
        if(me.charge_percent>=1.0){
            return amps;
        }
        if(me.charge_percent>=90){
            me.apply_load(-std.min(amps,me.charge_amps/3),dt);
            return std.max(0,amps-me.charge_amps/3);
        }
        me.apply_load(-std.min(amps,me.charge_amps),dt);
        return std.max(0,amps-me.charge_amps);
    }
}
            

##
# Set the current charge instantly to 100 %.
#

BatteryClass.reset_to_full_charge = func {
    me.apply_load(-(1.0 - me.charge_percent) * me.amp_hours, 3600);
}

##
# Generator model class.
#

var GeneratorClass = {};
# ************************************  John wrote: rpm_threshold is throwing an error, probably due to neither engine being "active". Need to evaluate how multi engine / generator setups do it, if at all **********
# ************************************  Arnd wrote: the c172p has two different engines to choose from, "active-engine" contains a copy of the chosen engine. ****
GeneratorClass.new = func (num){
    var obj = { parents : [GeneratorClass],
                rpm_source : "/engines/engine[" ~ num ~ "]/rpm",
                ammeter : "/systems/electrical/engine[" ~ num ~ "]/ammeter",
                rpm_threshold : 1400.0,
                ideal_volts : 28.0,
                ideal_amps : 200.0, 
                last_amps : "/systems/electrical/engine[" ~ num ~ "]/amps"};
    setprop( obj.rpm_source, 0.0 );
    setprop( obj.ammeter, 0.0 );
    setprop( obj.last_amps, 0.0 );
    return obj;
}

##
# Computes available amps and returns remaining amps after load is applied
#

GeneratorClass.apply_load = func( amps, dt ) {
    # No generator output for rpms < 1400.  For rpms >= 1400
    # give full output.  
    var rpm = getprop( me.rpm_source );
	var factor = 0;
    #var factor = rpm / me.rpm_threshold;
    #if ( factor > 1.0 ) {
	if (rpm >= me.rpm_threshold) {
        factor = 1.0;	
    }
    # print( "Generator amps = ", me.ideal_amps * factor );
    var available_amps = me.ideal_amps * factor;
    return available_amps - amps;
}

##
# Return output volts based on rpm
#

GeneratorClass.get_output_volts = func {
    # No generator output for rpms < 1400.  For rpms >= 1400
    # give full output.  
    var rpm = getprop( me.rpm_source );
    var factor = 0.000;
    var vfactor = 0.000;
	#var factor = rpm / me.rpm_threshold;
    #if ( factor > 1.0 ) {
	if (rpm >= me.rpm_threshold) {
        factor = 1.0;
    }
    
    # voltage sinks when a high load is applied
    vfactor = ((me.get_output_amps()-me.get_last_amps())/me.ideal_amps);
    # weaken effekt "full_load...no_load" to "1.05...0.8"
    vfactor = vfactor / 4 + 0.8;
    # print( "Generator volts = ", me.ideal_volts * factor * vfaktor );
    return me.ideal_volts * factor * vfactor;
}


##
# Return output amps available based on rpm.
#

GeneratorClass.get_output_amps = func {
    # Almost no generator output for rpms < 1400.  For rpms >= 1400
    # give full output.  
    var rpm = getprop( me.rpm_source );
    #var factor = 0;
	var factor = rpm / me.rpm_threshold;
    if ( factor < 0.9 ) {
        factor=factor*factor;
    }
	if (rpm >= me.rpm_threshold) {
        factor = 1.0;
    }
    # print( "Generator amps = ", ideal_amps * factor );
    return me.ideal_amps * factor;
}

##
# set ammeter reading
#

GeneratorClass.set_ammeter = func ( amps, volts, dt ) {
    # calculate watts at bus side of voltage regulator ( * effectivity^-1 )
    var power = amps * volts * 1.05;
    
    # then voltage at generator side of vreg (rated 28.5V@1400rpm) and amps
    volts = getprop( me.rpm_source ) / me.rpm_threshold * me.ideal_volts;
    volts = (volts + me.ideal_volts) / 2 * 1.02;
    amps = power / volts;
    
    # smooth out ammeter change (fps independent)
    var oldreading = getprop(me.ammeter);
    var ammeter = oldreading - (oldreading * dt) + (amps * dt);
    if (dt>=1){
        ammeter = amps;
    }
    # and set ammeter reading to sys/ele/eng[]/ammeter
    setprop( me.ammeter, ammeter );
}

##
# Don't tell me I forgot all set/get methods, here is one:
#
GeneratorClass.set_last_amps = func(last_amps){
    setprop(me.last_amps, last_amps);
}
GeneratorClass.get_last_amps = func{
    return getprop(me.last_amps);
}

# Need two batteries (Left and Right)
var battery1 = BatteryClass.new(0);
var battery2 = BatteryClass.new(1);
#Need two generators (Left and Right)
var Generator1 = GeneratorClass.new(0);
var Generator2 = GeneratorClass.new(1);


var reset_battery_and_circuit_breakers = func {
    # Charge battery to 100 %
    battery1.reset_to_full_charge();
    battery2.reset_to_full_charge();

    # Reset circuit breakers
    setprop("/controls/circuit-breakers/cockpit-light", 1);
    #setprop("/controls/circuit-breakers/left-booster-pump", 1);
    #setprop("/controls/circuit-breakers/right-booster-pump", 1);
    #setprop("/controls/circuit-breakers/gear-warn-lights", 1);
    #setprop("/controls/circuit-breakers/instr-panel-light", 1);
    #setprop("/controls/circuit-breakers/bcnlt", 1);
    #setprop("/controls/circuit-breakers/navlt",1);
    #setprop("/controls/circuit-breakers/cockpit-light",1);
    
    #setprop("/controls/circuit-breakers/pitot-heat", 1);
    
       
}

##
# This is the main electrical system update function.
#

var ElectricalSystemUpdater = {
    new : func {
        var m = {
            parents: [ElectricalSystemUpdater]
        };
        # Request that the update function be called each frame
        m.loop = updateloop.UpdateLoop.new(components: [m], update_period: 0.0, enable: 0);
        return m;
    },

    enable: func {
        me.loop.reset();
        me.loop.enable();
    },

    disable: func {
        me.loop.disable();
    },

    reset: func {
        # Do nothing
    },

    update: func (dt) {
        update_virtual_bus(dt);
    }
};

##
# Model the system of relays and connections that join the battery,
# Generator, starter, master/alt switches, external power supply.
#

var update_virtual_bus = func (dt) {
    var serviceable = getprop("/systems/electrical/serviceable");
    var external_volts = 0.0;
    var load = 0.0;
    var battery1_volts = 0.0;
    var battery2_volts = 0.0;
    var Generator1_volts = 0.0;
	var Generator2_volts = 0.0;

    # switch state
    var master_bat1 = getprop("/controls/switches/master-bat-1");
    var master_bat2 = getprop("/controls/switches/master-bat-2");
	var master_gen1 = getprop("/controls/switches/master-gen-1");
	var master_gen2 = getprop("/controls/switches/master-gen-2");
    
    # Volts after master switch (see overhead)
    if (master_bat1 and serviceable){
        battery1_volts = battery1.get_output_volts();
    }
    if (master_bat2 and serviceable){
        battery2_volts = battery2.get_output_volts();
    }
    if (master_gen1 and serviceable){
        Generator1_volts = Generator1.get_output_volts();
    }
    if (master_gen2 and serviceable){
        Generator2_volts = Generator2.get_output_volts();
    }
    
    if (getprop("/controls/electric/external-power")) {
        external_volts = 28;
    }
    
    # determine power source
    var power_source = nil;
    var bat1_load_norm = 0.0;
    var bat2_load_norm = 0.0;
    var gen1_load_norm = 0.0;
    var gen2_load_norm = 0.0;
    var usebatteries = 0;
    
    # how much is drawn of each battery when they have almost the same voltage (+-2V)
    if (battery1_volts>5.0 or battery2_volts>5.0){
        power_source = "batteries";
        usebatteries = 1;
        bat1_load_norm = ( battery1_volts-battery2_volts+2.0 ) /4.0;
        bat2_load_norm = ( battery2_volts-battery1_volts+2.0 ) /4.0;
        
        # more than +-2V difference: use one batterie only
        if (battery1_volts-battery2_volts>=2.0){
            bat1_load_norm = 1.0;
            bat2_load_norm = 0.0;
        } elsif(battery1_volts-battery2_volts<=-2.0){
            bat1_load_norm = 0.0;
            bat2_load_norm = 1.0;
        }
    }
    
    
    var bus_volts = 0.0;
    # find maximum voltage
    bus_volts = std.max(battery1_volts, battery2_volts);

    # how much is drawn of each generator when they have almost the same voltage (+-4V)
    if (Generator1_volts>bus_volts or Generator2_volts>bus_volts){
        power_source = "generators";
        usebatteries = 0;
        gen1_load_norm = ( Generator1_volts-Generator2_volts+4.0 ) /8.0;
        gen2_load_norm = ( Generator2_volts-Generator1_volts+4.0 ) /8.0;
        
        # more than +-2V difference: use one generator only
        if (Generator1_volts-Generator2_volts>=4.0){
            gen1_load_norm = 1.0;
            gen2_load_norm = 0.0;
        }elsif(Generator1_volts-Generator2_volts<=-4.0){
            gen1_load_norm = 0.0;
            gen2_load_norm = 1.0;
        }
        
        # calculate generator output voltage using the above ratio
        bus_volts = gen1_load_norm*Generator1_volts + gen2_load_norm*Generator2_volts;
        # Internal resistor of generators is much higher (current source rather than voltage source)
    }

    # External Input
    if ( external_volts > bus_volts ) {
        bus_volts = external_volts;
        power_source = "external";
        usebatteries = 0;
        gen1_load_norm = 0.0;
        gen2_load_norm = 0.0;
    }
    
    #Todo: HRU-28 Auxiliary power unit (putt-putt): 28 volt, 70 ampere DC, fuel for 90 min
    
    #print( "virtual bus volts = ", bus_volts );

    # bus network (1. these must be called in the right order
    load += electrical_bus_1(dt);
    load += avionics_bus_1();
    
	# **************************** TO DO ****************************
    # switch the master breaker off if load is out of limits
    #if ( load > 55 ) {
    #  bus_volts = 0;
    #}
    # Not sure if there is a master switch. But there is some sort of generator protection fuse
    # somewhere in the engine narcelle and only acessible from the ground
    
    
    var charge_amp=0.0;
    var available_charge_amp=0.0;
    # charge/discharge the battery
    if ( usebatteries ) {
        # discharge
        battery1.apply_load( load * bat1_load_norm, dt );
        battery2.apply_load( load * bat2_load_norm, dt );
    } elsif (master_bat1 or master_bat2) {
        # charge using either remaining gen amps or external amps
        if (power_source == "generators") {
            if(master_gen1){
                charge_amp = Generator1.apply_load(load*gen1_load_norm, dt);
            }
            if(master_gen2){
                charge_amp = charge_amp + Generator2.apply_load(load*gen2_load_norm, dt);
            }
        }
    }
    available_charge_amp=charge_amp;
    if (power_source == "external"){
        charge_amp = 500-load;
    }
    # then apply charge current to the batteries (ordered by their voltage)
    if(master_bat1 and battery1_volts<battery2_volts){
        charge_amp = battery1.charge_get_remaining(charge_amp, bus_volts, dt);
    }
    if(master_bat2){
        charge_amp = battery2.charge_get_remaining(charge_amp, bus_volts, dt);
    }
    if(master_bat1 and battery1_volts>battery2_volts){
        charge_amp = battery1.charge_get_remaining(charge_amp, bus_volts, dt);
    }
    
    # then apply load to generators - finally
    #load = load + available_charge_amp - charge_amp;
    
    Generator1.set_last_amps(load*gen1_load_norm);
    Generator2.set_last_amps(load*gen2_load_norm);
    Generator1.set_last_amps(0.0);
    Generator2.set_last_amps(0.0);

    # filter voltmeter/ammeter needle pos
    var voltmeter = 0.8 * getprop("/systems/electrical/voltmeter") + 0.2 * bus_volts;
    setprop("/systems/electrical/voltmeter", voltmeter);
    Generator1.set_ammeter(load*5*gen2_load_norm, bus_volts, dt);
    Generator2.set_ammeter(load*5*gen2_load_norm, bus_volts, dt);
    
    # outputs
    setprop("/systems/electrical/amps", load);
    setprop("/systems/electrical/volts", bus_volts);
    if (bus_volts > 6){
        vbus_volts = 0.8 * vbus_volts + 0.2 * bus_volts;
    }else{
        vbus_volts = 0.0;
    }
    return load;
}

# initialise voltmeter
setprop("/systems/electrical/voltmeter", 0.0);
var starter_overwrite = 0;#overwrite keyboard input
var starter_overwrite_r = 0;
var priming_s_l = 0.0;
var priming_s_r = 0.0;
setprop("/systems/electrical/outputs/priming-seconds-r",priming_s_r);
setprop("/systems/electrical/outputs/priming-seconds-l",priming_s_l);
#########
# Set bus load (main bus / avionics bus)
#########
# load=amps += volts / resistance (I = U / R, P=U*U/R)
# P = U*U/R -> P = 576/R, R = 576/P
#########
#   P/Watt | R/Ohm  at 24V
#    0.1   | 5760  white LED
#    0.6   |  960  Bicycle bulb
#    1.0   |  576  10 leds
#    8     |   72  medium pc fan
#   10     |   58  Refrigerator Bulb / 1m LED stripe
#   30     |   19  regular bulb
#   TBC...
var electrical_bus_1 = func(dt) {
    var bus_volts = 0.0;
    var load = 0.0;
    var annun_norm = getprop("/controls/lighting/annun-on-norm");# annunciator dimmer
    
    # TODO check master breaker
    if ( getprop("/controls/circuit-breakers/master") ) {
        # we are feed from the virtual bus
        bus_volts = vbus_volts;        
    }
    #print("Bus volts: ", bus_volts);
    
# ************* Panel ************************************#
    # Gear warn ligts
    if ( getprop("/controls/circuit-breakers/gear-warn-lights") ) {
        setprop("/systems/electrical/outputs/gear-warn-lights", bus_volts);
        # annun_norm is dimmer, only draws power when in use
        # yellow is inaccurate
        if(getprop("/gear/gear[0]/position-norm")>0)
            load += bus_volts / 1000 * annun_norm;
        if(getprop("/gear/gear[1]/position-norm")>0)
            load += bus_volts / 1000 * annun_norm;
        if(getprop("/gear/gear[2]/position-norm")>0)
            load += bus_volts / 1000 * annun_norm;
    } else {
        setprop("/systems/electrical/outputs/gear-warn-lights", 0.0);
    }
    
    # Hydraulic warning lights
    if ( getprop("/controls/switches/hyd-light") ) {
        setprop("/systems/electrical/outputs/hyd-light-norm", bus_volts/28);
        # hydraulic warning lights: steady from 2 to 45, blink above 95
        var pressl=getprop("/fdm/jsbsim/propulsion/engine[0]/oil-pressure-psi");
        var pressr=getprop("/fdm/jsbsim/propulsion/engine[1]/oil-pressure-psi");
        if(pressl>2 and pressl<45)
            load += bus_volts / 1000;
        if(pressl>97)
            load += bus_volts / 2000;
        if(pressr>2 and pressr<46)
            load += bus_volts / 1000;
        if(pressr>96)
            load += bus_volts / 2000;
    } else {
        setprop("/systems/electrical/outputs/hyd-light-norm", 0.0);
    }
    
    # Turn Coordinator and directional gyro Power  needed by instrument - no breaker found
    if ( getprop("/controls/circuit-breakers/turn-coordinator") ) {
        setprop("/systems/electrical/outputs/turn-coordinator", bus_volts);
        setprop("/systems/electrical/outputs/DG", bus_volts);
        load += bus_volts / 14;
    } else {
        setprop("/systems/electrical/outputs/turn-coordinator", 0.0);
        setprop("/systems/electrical/outputs/DG", 0.0);
    }
    
# ************* Heater and Anti-ice ****************************#
    
    # TODO: implement Pitot Heat Power - currently not more than a fuse
    if ( getprop("/controls/anti-ice/pitot-heat" ) and getprop("/controls/circuit-breakers/pitot-heat") ) {
        setprop("/systems/electrical/outputs/pitot-heat", bus_volts);
        #load += bus_volts / 28;
    } else {
        setprop("/systems/electrical/outputs/pitot-heat", 0.0);
    }
    
# ************* Lights Cockpit ************************************#
    # TBC Cabin Lights Power, todo, build cabin, or at least windows to light up;) and adjust load
    if ( getprop("/controls/circuit-breakers/cabinlt") and getprop("/controls/switches/cabinlt")) {
        setprop("/systems/electrical/outputs/cabin-lights", bus_volts);
        #load += bus_volts / 57;
    } else {
        setprop("/systems/electrical/outputs/cabin-lights", 0.0);
    }
    
    # Cockpit (Pedestal) Light Power
    if ( getprop("/controls/circuit-breakers/cockpit-light") ) {
        dome_out=getprop("/controls/lighting/cockpit-fwd-rheo")*bus_volts;
        setprop("/systems/electrical/outputs/cockpit-fwd-dome", dome_out);
        setprop("/systems/electrical/outputs/cockpit-fwd-norm", dome_out/28);
        load += (dome_out+0.001) / 57;#10W max
    } else {
        setprop("/systems/electrical/outputs/cockpit-fwd-dome", 0.0);
        setprop("/systems/electrical/outputs/cockpit-fwd-norm", 0.0);
    }
    
    # Cockpit Rear Dome Light Power
    if ( getprop("/controls/circuit-breakers/cockpit-light") and getprop("/controls/switches/rear-dome") ) {
        setprop("/systems/electrical/outputs/cockpit-rear-dome", bus_volts);
        setprop("/systems/electrical/outputs/cockpit-rear-norm", bus_volts/28);
        load += bus_volts / 57;
    } else {
        setprop("/systems/electrical/outputs/cockpit-rear-dome", 0.0);
        setprop("/systems/electrical/outputs/cockpit-rear-norm", 0.0);
    }
    
    # Panel lights
    if ( getprop("/controls/circuit-breakers/instlt") ) {
        panel_out = bus_volts * getprop("/controls/lighting/panel-rheo");
        setprop("/systems/electrical/outputs/panel-norm", panel_out/28*2);
        load += panel_out / 61;
    } else {
        setprop("/systems/electrical/outputs/panel-norm", 0.0);
    }
    
    # Instruments lights  works
    if ( getprop("/controls/circuit-breakers/instlt") ) {
        instrumentsrheo = bus_volts * getprop("/controls/lighting/instruments-rheo");
        setprop("/systems/electrical/outputs/instrument-lights", instrumentsrheo);
        setprop("/controls/lighting/instruments-norm", instrumentsrheo/24);
        load += instrumentsrheo / 57;
    } else {
        setprop("/systems/electrical/outputs/instrument-lights", 0.0);
    }
    
# ************* Engine management ************************************#    
    # Magnetos: accepts "{" key inputs (even if ignition=off) as well as overhead input
    # Inputs via the overhead 3d model will trigger an own method below this bus method
    # Inputs using "{" and "}" keys will be covered now
    var mag_key=getprop("/controls/engines/engine[0]/magnetos");
    var mag_swi=getprop("/controls/switches/magnetos-l");
    
    if(getprop("/controls/switches/master-ignition")==0){
        mag_swi=0;
    }
    
    if (mag_key != mag_swi){
        setprop("/controls/switches/magnetos-l", mag_key);
        if(mag_key>0){
            setprop("/controls/switches/master-ignition", 1);
        }
    }
    
    mag_key=getprop("/controls/engines/engine[1]/magnetos");
    mag_swi=getprop("/controls/switches/magnetos-r");
    if(getprop("/controls/switches/master-ignition")==0){
        mag_swi=0;
    }
    if (mag_key != mag_swi){
        setprop("/controls/switches/magnetos-r", mag_key);
        if(mag_key>0){
            setprop("/controls/switches/master-ignition", 1);
        }
    }
    
    # Engine Starter. TODO: search if the alternator is needed to do this
    if (bus_volts > 6) {
        if ( getprop("controls/switches/starter-l") ) {
            setprop("systems/electrical/outputs/starter-l", bus_volts);
            load += 24;
            setprop("controls/engines/engine[0]/starter", 1);
            starter_overwrite=1;# var defined above this bus method
        } elsif (starter_overwrite==1) {
            setprop("systems/electrical/outputs/starter-l", 0.0);
            setprop("controls/engines/engine[0]/starter", 0);
            starter_overwrite = 0;#set properties only once to not block keyboard input
        }
        
        if ( getprop("controls/switches/starter-r") ) {
            setprop("systems/electrical/outputs/starter-r", bus_volts);
            load += 24;
            setprop("controls/engines/engine[1]/starter", 1);
            starter_overwrite_r=1;# same as left engine - 
        } elsif (starter_overwrite_r==1) {
            setprop("systems/electrical/outputs/starter-r", 0.0);
            setprop("controls/engines/engine[1]/starter", 0);
            starter_overwrite_r = 0;#set properties only once to not block keyboard input
        }
    }else {
        # No electricity, overwrite even keyboard input
        setprop("systems/electrical/outputs/starter-l", 0.0);
        setprop("controls/engines/engine[0]/starter", 0);
        setprop("systems/electrical/outputs/starter-r", 0.0);
        setprop("controls/engines/engine[1]/starter", 0);
    }
    
    # Starters always draw a lot of current, no matter how they have been activated
    if(getprop("controls/engines/engine[0]/starter"))
        load += 24;
    if(getprop("controls/engines/engine[1]/starter"))
        load += 24;
    
    # fuel booster pump
    if ( getprop("/controls/circuit-breakers/fuel-booster-l") and getprop("/controls/fuel/boostpumps-l-high")) {
      setprop("/systems/electrical/outputs/fuel-booster-l", bus_volts);
      
      if(getprop("/controls/fuel/left-valve")>0)# fuel selectors not "off"
        load += bus_volts / 24;
        
    } else {
      setprop("/systems/electrical/outputs/fuel-booster-l", 0);
    }
    
    if ( getprop("/controls/circuit-breakers/fuel-booster-r") and getprop("/controls/fuel/boostpumps-r-high")) {
      setprop("/systems/electrical/outputs/fuel-booster-r", bus_volts);
      
      if(getprop("/controls/fuel/right-valve")>0)# fuel selectors not "off"
        load += bus_volts / 24;
        
    } else {
      setprop("/systems/electrical/outputs/fuel-booster-r", 0);
    }
    
    # TODO: Implement Priming for real!!! See /systems/fuel.xml at line 340  TODO
    # Fake priming - just showing "primed for x seconds" 
    if ( getprop("/controls/switches/priming-l") ) {
        priming_s_l += dt;
        gui.popupTip("Left engine priming: " ~ math.floor(priming_s_l) ~ "s", 2);
        load += bus_volts / 28;
    }elsif( priming_s_r > 0 and (getprop("/engines/engine[0]/cranking") or getprop("/engines/engine[0]/running"))){
        priming_s_l -= dt;
    }
    setprop("/systems/electrical/outputs/priming-seconds-l",priming_s_l);
    
    if ( getprop("/controls/switches/priming-r") ) {
        priming_s_r += dt;
        gui.popupTip("Right engine priming: " ~ math.floor(priming_s_r) ~ "s", 2);
        load += bus_volts / 28;
    }elsif( priming_s_r > 0 and (getprop("/engines/engine[1]/cranking") or getprop("/engines/engine[1]/running"))){
        priming_s_r -= dt;
    }
    setprop("/systems/electrical/outputs/priming-seconds-r",priming_s_r);
    
    
# ************* Aircraft Lights ************************************#
    # Landing Light Power - TODO define ALS and model exterior lights
    if ( getprop("/controls/circuit-breakers/landing")) {
        if ( getprop("/controls/switches/ldg-nose") or getprop("/controls/lighting/landing-lights") ){
            setprop("/systems/electrical/outputs/landing-light-nose", bus_volts);
            load += bus_volts / 10;
        } else {
        setprop("/systems/electrical/outputs/landing-light-nose", 0.0);
        }
        
        if( getprop("/controls/switches/ldg-right") or getprop("/controls/lighting/landing-lights") ){
            setprop("/systems/electrical/outputs/landing-light-right", bus_volts);
            load += bus_volts / 10;
        } else {
        setprop("/systems/electrical/outputs/landing-light-right", 0.0);
        }
        
        if ( getprop("/controls/switches/ldg-left") or getprop("/controls/lighting/landing-lights") ){
            setprop("/systems/electrical/outputs/landing-light-left", bus_volts);
            load += bus_volts / 10;
        } else {
        setprop("/systems/electrical/outputs/landing-light-left", 0.0);
        }
     
    } else {
        setprop("/systems/electrical/outputs/landing-lights-nose", 0.0 );
        setprop("/systems/electrical/outputs/landing-lights-right", 0.0 );
        setprop("/systems/electrical/outputs/landing-lights-left", 0.0 );
    }

    # Beacon Power
    if ( getprop("/controls/circuit-breakers/bcnlt") and getprop("/controls/switches/beacon" ) ) {
        setprop("/systems/electrical/outputs/beacon", bus_volts/20);
        load += bus_volts / 28;
    } else {
        setprop("/systems/electrical/outputs/beacon", 0.0);
    }
    
    # Nav Lights Power (breaker "position lights")
    if ( getprop("/controls/circuit-breakers/poslt") and getprop("/controls/lighting/nav-int" ) ) {
        setprop("/systems/electrical/outputs/nav-lights", bus_volts);
        load += bus_volts / 14;
    } else {
        setprop("/systems/electrical/outputs/nav-lights", 0.0);
    }

          
    # TODO Strobe Lights Power  not used
    if ( getprop("/controls/circuit-breakers/poslt") and getprop("/controls/lighting/strobe" ) ) {#(probably "belly" switch?)
        setprop("/systems/electrical/outputs/strobe", bus_volts);
        load += bus_volts / 14;
    } else {
        setprop("/systems/electrical/outputs/strobe", 0.0);
    }

    # register bus voltage
    ebus1_volts = bus_volts;

    # return cumulative load
    return load;
}

# These functions get called during changes to the overhead magnetos switch
var mag_l_changed = func() {
    var mag_panel = 0;
    
    if (getprop("/controls/switches/master-ignition")){
        mag_panel = getprop("/controls/switches/magnetos-l");
    }
    setprop("/controls/engines/engine[0]/magnetos",mag_panel);
}

var mag_r_changed = func() {
    var mag_panel = 0;
    
    if (getprop("/controls/switches/master-ignition")){
        mag_panel = getprop("/controls/switches/magnetos-r");
    }
    setprop("/controls/engines/engine[1]/magnetos",mag_panel);
}


var avionics_bus_1 = func() {
    var bus_volts = 0.0;
    var load = 0.0;
    
    # "Radios master" switch as ctrl/sw/master-avionics
    # we are fed from the electrical bus 1
	bus_volts = ebus1_volts;

    load += bus_volts / 20.0;

    # Avionics Fan Power
    #setprop("/systems/electrical/outputs/avionics-fan", bus_volts);

    # Audio Panel 1 Power not used
    if ( getprop("/controls/circuit-breakers/radio1") ) {
      setprop("/systems/electrical/outputs/audio-panel[0]", bus_volts);
    } else {
      setprop("/systems/electrical/outputs/audio-panel[0]", 0.0);
    }

    # Com and Nav 1 Power   not used
    if ( getprop("/controls/circuit-breakers/radio2") ) {
      setprop("/systems/electrical/outputs/nav[0]", bus_volts);
      setprop("systems/electrical/outputs/comm[0]", bus_volts);
    } else {
      setprop("/systems/electrical/outputs/nav[0]", 0.0);
      setprop("systems/electrical/outputs/comm[0]", 0.0);
    }
    
    # Com and Nav 2 Power   not used
    if ( getprop("/controls/circuit-breakers/radio3") ) {
      setprop("/systems/electrical/outputs/nav[1]", bus_volts);
      setprop("systems/electrical/outputs/comm[1]", bus_volts);
    } else {
      setprop("/systems/electrical/outputs/nav[1]", 0.0);
      setprop("systems/electrical/outputs/comm[1]", 0.0);
    }

    # Transponder Power   not used
    if ( getprop("/controls/circuit-breakers/radio4") ) {
      setprop("/systems/electrical/outputs/transponder", bus_volts);
    } else {
      setprop("/systems/electrical/outputs/transponder", 0.0);
    }
    
    # DME and ADF Power  not used
    if ( getprop("/controls/circuit-breakers/radio5") ) {
      setprop("/systems/electrical/outputs/dme", bus_volts);
      setprop("/systems/electrical/outputs/adf", bus_volts);
    } else {
      setprop("/systems/electrical/outputs/dme", 0.0);
      setprop("/systems/electrical/outputs/adf", 0.0);
    }

    # Autopilot Power   not used
    if ( getprop("/controls/circuit-breakers/autopilot") ) {
      setprop("/systems/electrical/outputs/autopilot", bus_volts);
    } else {
      setprop("/systems/electrical/outputs/autopilot", 0.0);
    }
    

    # return cumulative load
    return load;
}

############################ Utility function

#var flapsDown = controls.flapsDown;
#controls.flapsDown = func(v) {
#    flapsDown(v);
#    c172p.click("flaps");
#};

##
# Initialize the electrical system
#

var system_updater = ElectricalSystemUpdater.new();

setlistener("/sim/signals/fdm-initialized", func {
    # checking if battery should be automatically recharged
    if (!getprop("/systems/electrical/save-battery-charge")) {
        battery1.reset_to_full_charge();
        battery2.reset_to_full_charge();
    };

    system_updater.enable();
    print("C46 Nasal electrical system initialized");
});
