#include <Timer.h>
#include "../../includes/packet.h"

configuration ConnectionC{
    provides interface Connection;
}
implementation {
    components ConnectionP;
    Connection = ConnectionP.Connection;

    components new TimerMilliC() as myTimerA; 
	ConnectionP.connectTimer -> myTimerA;

    components new TimerMilliC() as myTimerC; 
	ConnectionP.connectTimerString -> myTimerC;

    components new TimerMilliC() as myTimerB; 
	ConnectionP.acceptTimer -> myTimerB;

    // components new HashmapC(int, 10) as SampleMap;
    // TransportP.sockets -> SampleMap;

    components TransportC;
    ConnectionP.Transport -> TransportC;
}