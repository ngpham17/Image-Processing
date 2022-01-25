# Image-Processing
Make a mux for the outputs to the VGA pins.
- Default is grey image
- Switch0: Toggle test image vertical bars generated from replicating bit4 of pixnum
- Switch1: Toggle Threshold image if greyscale is > {switches[6:4],1'b0}
- Switch2: Roberts cross edge detection greyscale image
- Switch3: Roberts cross greyscale image thresholded against {switches[6:4],1'b0}
