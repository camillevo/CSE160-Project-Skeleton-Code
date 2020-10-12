#include "../../includes/packet.h"

module NeighborP {
	provides interface Neighbor;
	uses interface SimpleSend;
	uses interface Random;
	uses interface LinkState;
	uses interface Timer<TMilli> as periodicTimerA; //Interface that was wired
	uses interface Timer<TMilli> as periodicTimerB;
	uses interface List<integer> as myList;
}

implementation {
	int neighbors[20] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
	int oldNeighbors[20] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
	lsPacket myPacket;

	int sequenceNum = 0;
	bool neighborsHaveSettled = 1;
	void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
	
	task void generateLSP();

	command error_t Neighbor.sendPackets(){
		pack neighborDiscoveryPacket;
		char neighborMessage[] = "ND";

		makePack(&neighborDiscoveryPacket, TOS_NODE_ID, AM_BROADCAST_ADDR, 5, PROTOCOL_NEIGHBORDISCOVERY, *(&sequenceNum), (uint8_t*) neighborMessage, PACKET_MAX_PAYLOAD_SIZE);

		call SimpleSend.send(neighborDiscoveryPacket, AM_BROADCAST_ADDR);
	}

	command void Neighbor.startNeighborDiscovery() {
		call periodicTimerA.startPeriodic(1000000);
		//call periodicTimerB.startPeriodic(50000);
		call Neighbor.sendPackets();
		*(&sequenceNum) = sequenceNum + 1;
	}

	event void periodicTimerA.fired() {
		memcpy(oldNeighbors, neighbors, sizeof(int)* 20);
		*(&sequenceNum) = sequenceNum + 1;
		call Neighbor.sendPackets();
	}

	event void periodicTimerB.fired() {
		// if (neighborsHaveSettled == 0) {
		// 	*(&neighborsHaveSettled) = 1;
		// 	if(call Neighbor.detectChange()) {
		// 		call Neighbor.printNeighbors();
		// 		call Neighbor.generateLSP();
		// 	}
		// }
		if(call Neighbor.detectChange()) {
			call Neighbor.printNeighbors();
			post generateLSP();
		}
	}

	task void generateLSP() {
		pack lsp;
		memcpy(myPacket.neighbors, neighbors, sizeof(int)* 20);
		myPacket.seqNum = sequenceNum;

		makePack(&lsp, TOS_NODE_ID, TOS_NODE_ID, 8, PROTOCOL_LINKSTATE, call Random.rand16() % 1000, (uint8_t*) neighbors, PACKET_MAX_PAYLOAD_SIZE);
		call LinkState.addLsp(&lsp);

		*(&sequenceNum) = sequenceNum + 1;
	}

	command bool Neighbor.detectChange() {
		int i;
		for(i = 0; i < 20; i++) {
			if(neighbors[i] != oldNeighbors[i]) {
				return 1;
			}
			if(neighbors[i] == 0) {
				return 0;
			}
		}
		return 0;
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
		*(&neighborsHaveSettled) = 0;
		call periodicTimerB.startOneShot(1000);
		return ret;
	}
	
	command void Neighbor.printNeighbors() {
		//dbg(GENERAL_CHANNEL, "Updated neighbors: %d has neighbors %d, %d, %d, %d, %d, %d, %d, %d\n", TOS_NODE_ID, neighbors[0], neighbors[1], neighbors[2], neighbors[3], neighbors[4], neighbors[5], neighbors[6], neighbors[7], neighbors[8]);
		int i;
		printf(" - Updated neighbors: %d has neighbors %d", TOS_NODE_ID, neighbors[0]);
		for (i  = 1; i < 20; i++) {
			if(neighbors[i] == 0) {
				break;
			}
			printf(", %d", neighbors[i]);
		}
		printf("\n");
	}
	
	command int * Neighbor.getNeighborArray() {
		return neighbors;
	}

	event void LinkState.routingTableReady() {}
	
	void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
		Package->src = src;
		Package->dest = dest;
		Package->TTL = TTL;
		Package->seq = seq;
		Package->protocol = protocol;
		memcpy(Package->payload, payload, length);
	}
}