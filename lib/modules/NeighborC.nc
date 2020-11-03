#include "../../includes/packet.h"

configuration NeighborC {
	provides interface Neighbor;
}

implementation {
	typedef int integer;

	components NeighborP;
	Neighbor = NeighborP.Neighbor;

	components RandomC;
	NeighborP.Random -> RandomC;

	components new SimpleSendC(AM_PACK);
	NeighborP.SimpleSend -> SimpleSendC;

	components new HashmapC(neighborWeight, 20) as hashmap;
	NeighborP.neighbors -> hashmap;

	components new TimerMilliC() as myTimerA; //create a new timer with alias “myTimerC”
	NeighborP.recheckNeighbors -> myTimerA; //Wire the interface to the component

	components new TimerMilliC() as myTimerB;
	NeighborP.checkNeighborsSettled -> myTimerB;

}