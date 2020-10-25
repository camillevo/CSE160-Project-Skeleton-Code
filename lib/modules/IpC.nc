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

    components new SimpleSendC(AM_PACK);
	IpP.SimpleSend -> SimpleSendC;

	components new ListC(pack, 20) as list;
	IpP.cache -> list;
}