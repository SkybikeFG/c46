# This nasal file reads the immatriculation number of a livery to print it on the panel 
# The number has to be like 
# Based on c172p registration_number.nas, 
# Edited for Curtiss C46 by me ;) in (late) 2018, GNU GPL v2p for sure

var read_immat = func () {
    immat=getprop("sim/model/livery/immatriculation");
    if (immat == nil)
        return;

    var glyph = nil;
    var immat_size = size(immat);

	if (immat_size > 6)
	    printf("Immatriculation too long. Only 6 allowed.");

	#convert to only uppercase letters
    if (immat_size != 0)
        immat = string.uc(immat);

    for (var i = 0; i < 6; i += 1) {
        if (i >= immat_size)
            glyph = -1;
        elsif (string.isupper(immat[i]))
            glyph = immat[i] - `A`;
        elsif (string.isdigit(immat[i]))
            glyph = immat[i] - `0` + 26;
        else
            glyph = 36;
		
        setprop("sim/model/immat/immat"~(i+1), glyph+1);
    }
};
setlistener("sim/model/livery/immatriculation", read_immat, 1, 0)

