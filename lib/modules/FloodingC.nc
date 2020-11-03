#include "../../includes/packet.h"

configuration FloodingC {
	provides interface Flooding;
	//uses interface HashMap<integer> as neighbors; 
}

implementation {
	components new AMReceiverC(AM_PACK) as GeneralReceive;
	FloodingP.Receive -> GeneralReceive;

	components FloodingP;
	Flooding = FloodingP.Flooding;

	components NeighborC;
	FloodingP.Neighbor -> NeighborC;
	
	components new SimpleSendC(AM_PACK);
	FloodingP.SimpleSend -> SimpleSendC;

	components new ListC(floodingPacket, 20) as list;
	FloodingP.cache -> list;

}