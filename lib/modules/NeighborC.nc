#include "../../includes/packet.h"

configuration NeighborC {
	provides interface Neighbor;
	//uses interface HashMap<integer> as neighbors;
}

implementation {
	typedef int integer;

	components NeighborP;
	Neighbor = NeighborP.Neighbor;
	
	components new SimpleSendC(AM_PACK);
	NeighborP.SimpleSend -> SimpleSendC;

	components new TimerMilliC() as myTimerC; //create a new timer with alias “myTimerC”
	NeighborP.periodicTimer -> myTimerC; //Wire the interface to the component
	
	//components new HashMapC(integer, 9);
	//NeighborP.neighbors = neighbors;

}