#include "../../includes/packet.h"

module FloodingP {
	provides interface Flooding;
	
	uses interface SimpleSend;
	uses interface Neighbor;
	uses interface Timer<TMilli> as Timer; 

}

implementation {
	int cache[20][20];
	bool haveNeighborsSettled = TRUE;
	pack packToSend;
	uint16_t frm;
	uint16_t dest;
	
	bool checkCache(int src, int seqNum) {
		int i;
		for(i = 0; i < 20; i++) {
			if(cache[src - 1][i] == seqNum) {
				return 0;
			}
			if(cache[src - 1][i] == 0) {
				cache[src - 1][i] = seqNum;
				return 1;
			}
		}
		return 0;
	}

	event void Neighbor.neighborsHaveSettled() {
		haveNeighborsSettled = TRUE;
	}

	event void Timer.fired() {
		call Flooding.floodSend(packToSend, frm, dest);
	}
	
	command void Flooding.floodSend(pack x, uint16_t from, uint16_t destination) {
		int i;
		uint8_t * neighbors;
		
		if(haveNeighborsSettled == FALSE) {
			packToSend = x;
			frm = from;
			dest = destination;
			dbg(GENERAL_CHANNEL, "Neighbors have note settled. Waiting 1200 Clicks.\n");
			call Timer.startOneShot(1200);
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
			if(neighbors[i] == x.src) {
				continue;
			}
			if(neighbors[i] == 0) {
				return;
			}
			call SimpleSend.send(x, neighbors[i]);
			
		}
			
	}
	
}