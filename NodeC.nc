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


    Node -> MainC.Boot;

    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC;

    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;
	
	components NeighborC;
	Node.Neighbor -> NeighborC;

    components TransportC;
    Node.Transport -> TransportC;

    components LinkStateC;
    Node.LinkState ->LinkStateC;

    components IpC;
    Node.Ip->IpC;
}
