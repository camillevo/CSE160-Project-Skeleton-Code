#include "../../includes/packet.h"

configuration IpC{
  provides interface Ip;
}
implementation{
    components IpP;
    Ip = IpP.Ip;

    components LinkStateC;
    IpP.LinkState -> LinkStateC;

    components new SimpleSendC(AM_PACK);
	IpP.SimpleSend -> SimpleSendC;

    components new TimerMilliC() as myTimerA; //create a new timer with alias “myTimerC”
	IpP.waitForRoutingTable -> myTimerA;
}