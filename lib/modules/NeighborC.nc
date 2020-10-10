#include "../../includes/packet.h"

configuration NeighborC {
	provides interface Neighbor;
}

implementation {
	typedef int integer;

	components NeighborP;
	Neighbor = NeighborP.Neighbor;
	
	components FloodingC;
	NeighborP.Flooding -> FloodingC;

	components new SimpleSendC(AM_PACK);
	NeighborP.SimpleSend -> SimpleSendC;

	components new ListC(integer, 20);
	NeighborP.myList -> ListC;

	components new TimerMilliC() as myTimerA; //create a new timer with alias “myTimerC”
	NeighborP.periodicTimerA -> myTimerA; //Wire the interface to the component

	components new TimerMilliC() as myTimerB;
	NeighborP.periodicTimerB -> myTimerB;

}