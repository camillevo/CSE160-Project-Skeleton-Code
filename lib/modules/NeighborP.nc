#include "../../includes/packet.h"

module NeighborP {
	provides interface Neighbor;
	uses interface SimpleSend;
	//uses interface HashMap<integer> as neighbors;
	uses interface Random;
	uses interface Timer<TMilli> as periodicTimer; //Interface that was wired
}

implementation {
	int neighbors[20] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
	/*
	command error_t Neighbor.testHashmap() {
		call neighbors.insert(1, sample);
		call neighbors.insert(5, sample);
		
		keys = call neighbors.getKeys();
		
		dbg(GENERAL_CHANNEL, "keys %d\n", *keys);
	}*/
	
	command error_t Neighbor.sendPackets(pack x){
		call Node.makePack
		call SimpleSend.send(x, AM_BROADCAST_ADDR);
	}
	
	command bool Neighbor.findNeighbor(int x) {
		int i;
		int ret;
		for(i = 0; i < 20; i++) {
			if (neighbors[i] == x) {
				ret = 1;
				break;
			}
			if (neighbors[i] == 0) {
				neighbors[i] = x;
				ret = 0;
				break;
			}
		}
		
		dbg(GENERAL_CHANNEL, "found neighbor %d. neighbors are now [%d, %d, %d, %d, %d, %d]\n", x, neighbors[0], neighbors[1], neighbors[2], neighbors[3], neighbors[4], neighbors[5], neighbors[6]);
		
		return ret;
	}
	
	
	command void Neighbor.printNeighbors() {
		dbg(GENERAL_CHANNEL, "neighbors are now %d, %d, %d, %d, %d, %d, %d, %d\n", neighbors[0], neighbors[1], neighbors[2], neighbors[3], neighbors[4], neighbors[5], neighbors[6], neighbors[7], neighbors[8]);
	}
	
	command int * Neighbor.getNeighborArray() {
		return neighbors;
	}
	
}