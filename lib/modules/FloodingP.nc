#include "../../includes/packet.h"

module FloodingP {
	provides interface Flooding;
	
	uses interface SimpleSend;
	uses interface Receive;
	uses interface Neighbor;
	uses interface List<floodingPacket> as cache;
}

implementation {
	int seqNums[30][30];
	bool haveNeighborsSettled = FALSE;
	
	bool checkCache(int src, int seqNum) {
		int i;
		for(i = 0; i < 30; i++) {
			if(seqNums[src - 1][i] == seqNum) {
				return 0;
			}
			if(seqNums[src - 1][i] == 0) {
				seqNums[src - 1][i] = seqNum;
				return 1;
			}
		}
		return 0;
	}

	event void Neighbor.neighborsHaveSettled() {
		int size = call cache.size();
		int i;
		haveNeighborsSettled = TRUE;
		for(i = 0; i < size; i++) {
			floodingPacket curr = call cache.popfront();
			//dbg(GENERAL_CHANNEL, "Sending packet from %d from my cache out now\n", curr.frm);
			call Flooding.floodSend(curr.packToSend, curr.frm, curr.dest);
		}
	}
	
	command void Flooding.floodSend(pack x, uint16_t from, uint16_t destination) {
		int i;
		uint8_t * neighbors;

		if(haveNeighborsSettled == FALSE) {
			floodingPacket currPack;
			currPack.packToSend = x;
			currPack.frm = from;
			currPack.dest = destination;
			call cache.pushback(currPack);
			return;
		}

 		neighbors = call Neighbor.getNeighborArray();
		
		if((checkCache(from, x.seq) == 0) || x.TTL < 0) {
			return;
		}
		for(i = 0; i < 30; i++) {
			if(destination != 0 && neighbors[i] == destination) {
				if(x.src == 6) {
					dbg(GENERAL_CHANNEL, "Sent 6's lsp to %d\n", neighbors[i]);
				}
				call SimpleSend.send(x, neighbors[i]);
				return;
			}
		}	
		
		for(i = 0; i < 30; i++) {
			if(neighbors[i] == from) {
				continue;
			}

			if(neighbors[i] == 0) {
				return;
			}
			if(x.src == 6) {
					dbg(GENERAL_CHANNEL, "Sent 6's lsp to %d\n", neighbors[i]);
				}
			call SimpleSend.send(x, neighbors[i]);	
		}
	
	}

	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
		if(len==sizeof(pack)){
			pack* myMsg=(pack*) payload;

			switch(myMsg->protocol) {
				case PROTOCOL_NEIGHBORDISCOVERY:
				{
					pack packToSend;
					packToSend.protocol = PROTOCOL_NEIGHBORRESPONSE;
					packToSend.src = TOS_NODE_ID;
					call SimpleSend.send(packToSend, myMsg->src);
				}
					break;
				case PROTOCOL_NEIGHBORRESPONSE:
					call Neighbor.processNeighborResponse(myMsg->src);
					break;

			}
			return msg;
		}
		dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
		return msg;
	}
	
}