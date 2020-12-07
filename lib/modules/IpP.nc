#include "../../includes/packet.h"

module IpP{
    provides interface Ip;
    uses interface Receive;
    uses interface LinkState;
    uses interface SimpleSend;
    uses interface List<pack> as cache;
    uses interface Timer<TMilli> as checkCache;
    uses interface Transport;
}

implementation{
    bool routingTableReady = FALSE;
    pack *myPacket;

    event void LinkState.routingTableReady() {
        int size = call cache.size();
		int i;
		routingTableReady = TRUE;
		for(i = 0; i < size; i++) {
			dbg(GENERAL_CHANNEL, "Sending packet from my cache out now\n");
			call Ip.ping(call cache.popfront());
		}
    }

    event void checkCache.fired() {
        int size = call cache.size();
		int i;
		for(i = 0; i < size; i++) {
			dbg(GENERAL_CHANNEL, "Sending packet from my cache out now\n");
			call Ip.ping(call cache.popfront());
		}
    }

    command void Ip.ping(pack sendPacket){
        if(routingTableReady == FALSE || call LinkState.getNextHop(sendPacket.dest) == 0) {
            call cache.pushback(sendPacket);
            call checkCache.startOneShot(2000);
            return;
        }
        //printf("Sending packet from %d to %d\n", TOS_NODE_ID, call LinkState.getNextHop(sendPacket.dest));
        call SimpleSend.send(sendPacket, call LinkState.getNextHop(sendPacket.dest));
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
		if(len==sizeof(pack)){
			pack* myMsg=(pack*) payload;

			switch(myMsg->protocol) {
				case PROTOCOL_LINKSTATE:
                    call LinkState.addLsp(myMsg);
					break;
                case PROTOCOL_PING:
                    //printf("%d received.\n", TOS_NODE_ID);
                    if(myMsg->dest != TOS_NODE_ID) {
                        myMsg->TTL = myMsg->TTL - 1;
                        call Ip.ping(*myMsg);
                    } else {
                        dbg(GENERAL_CHANNEL, "Packet Received\n");
			            dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
                    }
                    break;
                case PROTOCOL_TCP:
                    if(myMsg->dest != TOS_NODE_ID) {
                        myMsg->TTL = myMsg->TTL - 1;
                        call Ip.ping(*myMsg);
                    } else {
                        call Transport.receive(myMsg);
                    }
                    break;
			}
			return msg;
		}
		dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
		return msg;
	}
}
