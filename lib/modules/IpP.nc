#include "../../includes/packet.h"

module IpP{
    provides interface Ip;
    uses interface Receive;
    uses interface LinkState;
    uses interface SimpleSend;
    uses interface List<floodingPacket> as cache;
}

implementation{
    bool routingTableReady = FALSE;
    pack *myPacket;

    event void LinkState.routingTableReady() {
        routingTableReady = TRUE;
    }

    command void Ip.ping(pack sendPacket){
        myPacket = &sendPacket;
        if(routingTableReady == FALSE) {
            printf("routing table not ready\n");
            // If routing table hasn't been generated, generate it
            call LinkState.findShortestPath();
            call waitForRoutingTable.startOneShot(1000);
        }
        printf("Sending packet from %d to %d\n", TOS_NODE_ID, call LinkState.getNextHop(sendPacket.dest));
        call SimpleSend.send(sendPacket, call LinkState.getNextHop(sendPacket.dest));
    }

    event void waitForRoutingTable.fired() {
        call Ip.ping(*myPacket);
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
		if(len==sizeof(pack)){
			pack* myMsg=(pack*) payload;

			switch(myMsg->protocol) {
				case PROTOCOL_LINKSTATE:
                    call LinkState.addLsp(myMsg);
					break;
			}
            
            if(myMsg->dest != TOS_NODE_ID) {
                call Ip.ping();
            }

            dbg(GENERAL_CHANNEL, "Packet Received\n");
			
			dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
			return msg;
		}
		dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
		return msg;
	}
}
