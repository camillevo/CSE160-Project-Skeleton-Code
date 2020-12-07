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

    components new TimerMilliC() as myTimerB; 
	ConnectionP.acceptTimer -> myTimerB;

    components TransportC;
    ConnectionP.Transport -> TransportC;
}