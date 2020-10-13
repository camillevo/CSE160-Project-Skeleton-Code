#include "../../includes/packet.h"

module NeighborP {
	provides interface Neighbor;
	uses interface SimpleSend;
	uses interface Random;
	uses interface LinkState;
	uses interface Timer<TMilli> as periodicTimerA; //Interface that was wired
	uses interface Timer<TMilli> as checkNeighborsSettled;
	uses interface List<integer> as myList;
}

implementation {
	uint8_t confirmedNeighbors[20] = {0}; //Existing set of neighbors
	uint8_t neighbors[20] = {0}; // temp set of new neighbors
	lsPacket myPacket;

	int sequenceNum = 0;
	void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
	
	void resetNeighborArray();
	void generateLSP();
	bool detectChange();
	error_t sendPackets();

	error_t sendPackets(){
		pack neighborDiscoveryPacket;
		char neighborMessage[] = "ND";

		makePack(&neighborDiscoveryPacket, TOS_NODE_ID, AM_BROADCAST_ADDR, 5, PROTOCOL_NEIGHBORDISCOVERY, *(&sequenceNum), (uint8_t*) neighborMessage, PACKET_MAX_PAYLOAD_SIZE);

		call SimpleSend.send(neighborDiscoveryPacket, AM_BROADCAST_ADDR);
	}

	command void Neighbor.startNeighborDiscovery() {
		call periodicTimerA.startPeriodic(1000000 + call Random.rand16()%100000);
		sendPackets();
		*(&sequenceNum) = sequenceNum + 1;
	}

	event void periodicTimerA.fired() {
		resetNeighborArray();
		if(TOS_NODE_ID == 2 || TOS_NODE_ID == 6) {dbg(GENERAL_CHANNEL, "time to recheck neighbors\n");}
		//memcpy(oldNeighbors, neighbors, sizeof(uint8_t)* 20);
		*(&sequenceNum) = sequenceNum + 1;
		sendPackets();
	}

	event void checkNeighborsSettled.fired() {
		if(detectChange()) {
			memcpy(confirmedNeighbors, neighbors, sizeof(uint8_t)* 20);
			call Neighbor.printNeighbors();
			signal LinkState.routingTableReady(FALSE);
			generateLSP();
		}
	}

	void generateLSP() {
		pack lsp;
		memcpy(myPacket.neighbors, neighbors, sizeof(uint8_t)* 20);
		myPacket.seqNum = sequenceNum;

		makePack(&lsp, TOS_NODE_ID, 0, 8, PROTOCOL_LINKSTATE, call Random.rand16() % 1000, (uint8_t*) confirmedNeighbors, PACKET_MAX_PAYLOAD_SIZE);
		call LinkState.addLsp(&lsp);

		*(&sequenceNum) = sequenceNum + 1;
	}

	bool detectChange() {
		// We will use a method similar to hashing, but with an array
		int i = 0;
		uint8_t temp[20] = {0};
		
		while(neighbors[i] > 0) {
			temp[neighbors[i]] = 1;
			i++;
		}
		//printf("temp[%d, %d, %d, %d, %d, %d, %d, %d, %d]\n", temp[0], temp[1], temp[2], temp[3], temp[4], temp[5], temp[6], temp[7], temp[8]);
		for(i = 0; i < 20; i++) {
			if(neighbors[i] == 0) {
				if(confirmedNeighbors[i] == 0) { return FALSE; }
				else { return TRUE; }
			} 
			if(temp[confirmedNeighbors[i]] == 0) {
				call LinkState.nodeDown(confirmedNeighbors[i]);
				return TRUE;
			}
		}
		return FALSE;
	}
	
	command bool Neighbor.findNeighbor(int x) {
		int i;
		int ret;
		for(i = 0; i < 20; i++) {
			if (neighbors[i] == (uint8_t) x) {
				ret = 1;
				break;
			}
			if (neighbors[i] == 0) {
				neighbors[i] = (uint8_t) x;
				ret = 0;
				break;
			}
		}
		call checkNeighborsSettled.startOneShot(108043);
		return ret;
	}
	
	command void Neighbor.printNeighbors() {
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
	
	command uint8_t * Neighbor.getNeighborArray() {
		return confirmedNeighbors;
	}

	event void LinkState.routingTableReady(bool y) {}

	void resetNeighborArray() {
		int i = 0;
		while(neighbors[i] != 0) {
			neighbors[i] = 0;
			i++;
		}
	}
	
	void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
		Package->src = src;
		Package->dest = dest;
		Package->TTL = TTL;
		Package->seq = seq;
		Package->protocol = protocol;
		memcpy(Package->payload, payload, length);
	}
}