#include "../../includes/packet.h"

module FloodingP {
	provides interface Flooding;
	
	uses interface SimpleSend;
}

implementation {
	int cache[20][20];
	
	command bool Flooding.checkCache(int src, int seqNum) {
		int i;
		for(i = 0; i < 20; i++) {
			if(cache[src - 1][i] == seqNum) {
				return 0;
			}
			if(cache[src - 1][i] == 0) {
				cache[src - 1][i] = seqNum;
				dbg(GENERAL_CHANNEL, "put seq in index %d\n", i);
				return 1;
			}
		}
	}
	
	command void Flooding.floodSend(pack x, int* neighborArr) {
		int i;
		for(i = 0; i < 2; i++) {
			dbg(GENERAL_CHANNEL, "checkpoint 2. upcoming neighbot is %d\n", neighborArr[i]);
			if(neighborArr[i] == 0) {
				return;
			}
			dbg(GENERAL_CHANNEL, "sent flooding packet to %d\n", neighborArr[i]);
			call SimpleSend.send(x, neighborArr[i]);
		}
			
	}
	
}