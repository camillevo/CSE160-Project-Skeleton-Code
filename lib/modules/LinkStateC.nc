#include "../../includes/packet.h"

configuration LinkStateC {
	provides interface LinkState;
}

implementation {
	components LinkStateP;
	LinkState = LinkStateP.LinkState;

	components FloodingC;
	LinkStateP.Flooding -> FloodingC;

	components new SimpleSendC(AM_PACK);
	LinkStateP.SimpleSend -> SimpleSendC;

	components new HashmapC(neighborPair, 20) as myListA;
	LinkStateP.confirmed -> myListA;

	components new HashmapC(neighborPair, 20) as myListB;
	LinkStateP.tentative -> myListB;

	components new TimerMilliC() as myTimerA; //create a new timer with alias “myTimerC”
	LinkStateP.myTimer -> myTimerA; //Wire the interface to the component

}