################
# models a clock with offset, including options to select UTC, local, pilot/copilots time,...
# Original by curtiss c46 team, Arnd Lebert in 2018, GNU GPL v2+
################
var clock = {
    new : func(base) {
        var m = { parents: [clock] };
        m.base = base;
        m.baseN = props.globals.getNode( m.base, 1 );
		
		m.offset = m.baseN.initNode( "offset-sec", 0 );
		m.timeSec = m.baseN.initNode( "time-sec", 0 );
		
		return m;
	},
	
	update : func {
	    me.timeSec.setValue( me.offset.getValue() + getprop("sim/time/utc/day-seconds") );
		},
};

var clock_0 = clock.new( "/instrumentation/clock[3]" );
	