#include "../../includes/packet.h"

configuration IpC{
    provides interface Ip;
}
implementation{
    components IpP;
    Ip = IpP.Ip;
    
    components new AMReceiverC(AM_PACK) as GeneralReceive;
    IpP.Receive -> GeneralReceive;

    components LinkStateC;
    IpP.LinkState -> LinkStateC;

    components TransportC;
    IpP.Transport -> TransportC;
  
    components new TimerMilliC() as myTimerA; //create a new timer with alias “myTimerC”
    IpP.checkCache -> myTimerA;

    components new SimpleSendC(AM_PACK);
	IpP.SimpleSend -> SimpleSendC;

	components new ListC(pack, 20) as list;
	IpP.cache -> list;
}