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

    event void LinkState.routingTableReady() {
        routingTableReady = TRUE;
        //dbg(GENERAL_CHANNEL, "routing table finished: ip module\n");
    }

    command bool Ip.ping(pack sendPacket){
        myPacket = &sendPacket;
        if(routingTableReady == FALSE) {
            call waitForRoutingTable.startOneShot(1000);
        }
        
        call SimpleSend.send(sendPacket, call LinkState.getNextHop(sendPacket.dest));
    }

    event void waitForRoutingTable.fired() {
        call Ip.ping(*myPacket);
    }
}
