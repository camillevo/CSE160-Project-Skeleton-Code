#include "../../includes/packet.h"

module FloodingP {
	provides interface Flooding;
	
	uses interface SimpleSend;
	uses interface Neighbor;
}

implementation {
	int cache[20][20];
	
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
	
	command void Flooding.floodSend(pack x, uint16_t from, uint16_t destination) {
		int i;
		uint8_t * neighbors;
		// check if node is already neighbors with destination
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
			if(neighbors[i] == 0) {
				return;
			}
			call SimpleSend.send(x, neighbors[i]);
			
		}
			
	}
	
}