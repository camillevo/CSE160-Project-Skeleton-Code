#include "../../includes/packet.h"

module IpP{
    provides interface Ip;
    uses interface LinkState;
    uses interface SimpleSend;
    uses interface Timer<TMilli> as waitForRoutingTable;
}

implementation{
    bool routingTableReady = FALSE;
    pack *myPacket;

    event void LinkState.routingTableReady(bool y) {
        routingTableReady = y;
    }

    command void Ip.ping(pack sendPacket){
        myPacket = &sendPacket;
        if(routingTableReady == FALSE) {
            printf("routing table not ready\n");
            // If routing table hasn't been generated, generate it
            call LinkState.findShortestPath();
            //call waitForRoutingTable.startOneShot(1000);
        }
        printf("sending packet from %d to %d\n", TOS_NODE_ID, call LinkState.getNextHop(sendPacket.dest));
        call SimpleSend.send(sendPacket, call LinkState.getNextHop(sendPacket.dest));
    }

    event void waitForRoutingTable.fired() {
        call Ip.ping(*myPacket);
    }
}
