/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */

#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"

configuration NodeC{
}
implementation {
    components MainC;
    components Node;
    components new AMReceiverC(AM_PACK) as GeneralReceive;


    Node -> MainC.Boot;

    Node.Receive -> GeneralReceive;

    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC;

    components new SimpleSendC(AM_PACK);
    Node.Sender -> SimpleSendC;
	
	components sampleC as sampleMod;
	Node.sampleMod -> sampleMod;

    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;
	
	components NeighborC;
	Node.Neighbor->NeighborC;
	
	components FloodingC;
	Node.Flooding->FloodingC;
	
	components new TimerMilliC() as myTimerC; //create a new timer with alias “myTimerC”
	Node.Boot -> MainC.Boot;
	Node.periodicTimer -> myTimerC; //Wire the interface to the component
}
