#include "../../includes/packet.h"

configuration FloodingC {
	provides interface Flooding;
	//uses interface HashMap<integer> as neighbors; 
}

implementation {
	typedef int integer;

	components FloodingP;
	Flooding = FloodingP.Flooding;

	components NeighborC;
	FloodingP.Neighbor -> NeighborC;
	
	components new SimpleSendC(AM_PACK);
	FloodingP.SimpleSend -> SimpleSendC;
	
	//components new HashMapC(integer, 9);
	//NeighborP.neighbors = neighbors;

}