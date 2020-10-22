#include "../../includes/packet.h"

module FloodingP {
	provides interface Flooding;
	
	uses interface SimpleSend;
	uses interface Receive;
	uses interface Neighbor;
	uses interface List<floodingPacket> as cache;
}

implementation {
	int seqNums[20][20];
	bool haveNeighborsSettled = FALSE;
	
	bool checkCache(int src, int seqNum) {
		int i;
		for(i = 0; i < 20; i++) {
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
			//dbg(GENERAL_CHANNEL, "Neighbors have not settled. Adding to message from %d to cache.\n", from);
		}

 		neighbors = call Neighbor.getNeighborArray();
		
		if((checkCache(from, x.seq) == 0) || x.TTL < 0) {
			return;
		}
		
		for(i = 0; i < 20; i++) {
			if(destination != 0 && neighbors[i] == destination) {
				call SimpleSend.send(x, neighbors[i]);
				return;
			}
		}	
		for(i = 0; i < 20; i++) {
			if(neighbors[i] == from) {
				continue;
			}
			// if(neighbors[i] == x.src) {
			// 	continue;
			// }
			if(neighbors[i] == 0) {
				return;
			}
			if(TOS_NODE_ID == 2 || TOS_NODE_ID == 4) {
				dbg(GENERAL_CHANNEL, "Sending %d's lsp to node %d. seqNum = %d\n", x.src, neighbors[i],x.seq);
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
	}
	
}