####################################################################
# KR85  - Arnd lebert - Curtiss c46 - 2018 - GNUGPLv2+ - based on c172P kr87

var kr85 = {
    new : func(base) {
        var m = { parents: [kr85] };
        m.base = base;
        m.baseN = props.globals.getNode( m.base, 1 );

        # will be set from audiopanel
        # m.baseN.getNode( "ident-audible" ).setBoolValue( 1 );
        m.volumeNormN = m.baseN.initNode( "volume-norm", 0.1 );
        m.power = 0;
		m.modesButtonN = m.baseN.initNode( "modes", 0, "INT" );		
        m.powerButtonN = m.baseN.initNode( "power-btn", 0, "BOOL" ); 

        m.modeN = m.baseN.getNode( "mode" );
        aircraft.data.add(
            m.modesButtonN,
            m.volumeNormN, 
            m.powerButtonN,
            m.baseN.getNode( "frequencies/selected-khz", 1 )
        );
		
		m.modesNames = ["adf", "adf", "ant", "bfo"];
		
		setlistener( m.base ~ "/modes", func { m.modeButtonListener() } );
        m.modeButtonListener();

        return m;
    },

    modeButtonListener : func {
	    me.modeN.setValue( me.modesNames[ me.modesButtonN.getValue()] );
		if( me.modesButtonN.getValue() == 0){
			me.powerButtonN.setValue( "power-btn", 0 );
			}else{
			me.powerButtonN.setValue( "power-btn", 1 );
			}
    },
};

var kr85_0 = kr85.new( "/instrumentation/adf[0]" );#.update();

#setlistener("/sim/signals/fdm-initialized", func { timer_update() } );
