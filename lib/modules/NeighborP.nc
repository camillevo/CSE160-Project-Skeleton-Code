#include "../../includes/packet.h"

module NeighborP {
	provides interface Neighbor;
	uses interface SimpleSend;
	uses interface Random;
	uses interface Timer<TMilli> as recheckNeighbors; //Interface that was wired
	uses interface Timer<TMilli> as checkNeighborsSettled;
	uses interface Hashmap<neighborWeight> as neighbors;
}

implementation {
	uint8_t finalizedNeighbors[20];
	int movingWindowCurrIndex = 0;
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
	void printNeighbors();
	

	command void Neighbor.startNeighborDiscovery() {
		pack neighborDiscoveryPacket;
		char neighborMessage[] = "ND";
		int i;
		uint32_t *keys = call neighbors.getKeys();

		movingWindowCurrIndex = (movingWindowCurrIndex + 1) % 3;
		for(i = 0; i < call neighbors.size(); i++) {
			neighborWeight *curr = call neighbors.getPointer(keys[i]);
			curr->weights[movingWindowCurrIndex] = 0;
		}

		makePack(&neighborDiscoveryPacket, TOS_NODE_ID, AM_BROADCAST_ADDR, 5, PROTOCOL_NEIGHBORDISCOVERY, 0, (uint8_t*) neighborMessage, PACKET_MAX_PAYLOAD_SIZE);
		call SimpleSend.send(neighborDiscoveryPacket, AM_BROADCAST_ADDR);
	}

	command void Neighbor.processNeighborResponse(int node) {
		if(call neighbors.contains(node)) {
			neighborWeight *currNeighbor = call neighbors.getPointer(node);
			currNeighbor->weights[movingWindowCurrIndex] = 1;
		}
		else {
			neighborWeight curr;
			curr.node = node;
			// If a new node is discovered, make all indicies true
			curr.weights[0] = 1;
			curr.weights[1] = 1;
			curr.weights[2] = 1;
			call neighbors.insert(node, curr);
		}
		call checkNeighborsSettled.startOneShot(7689);
	}

	event void checkNeighborsSettled.fired() {
		int i;
		bool haveNeighborsChanged = FALSE;
		uint32_t *keys = call neighbors.getKeys();

		for(i = 0; i < call neighbors.size(); i++) {
			neighborWeight *curr = call neighbors.getPointer(keys[i]);
			float avg = (curr->weights[0] + curr->weights[1] + curr->weights[2]) / (float) 3;

			if(avg > 0.30) {
				if(curr->confirmedNeighbor != TRUE) {
					haveNeighborsChanged = TRUE;
					curr->confirmedNeighbor = TRUE;
				}
			} else {
				if(curr->confirmedNeighbor != FALSE) {
					haveNeighborsChanged = TRUE;
					curr->confirmedNeighbor = FALSE;
				}
			}
		}
		if(haveNeighborsChanged) {
			printNeighbors();
			signal Neighbor.neighborsHaveSettled();
		}
		call recheckNeighbors.startOneShot(89834);
	}

	event void recheckNeighbors.fired() {
		call Neighbor.startNeighborDiscovery();
	}

	void printNeighbors() {
		int i;
		uint32_t *keys = call neighbors.getKeys();
		dbg(GENERAL_CHANNEL, "neighbors: ");
		for(i = 0; i < 6; i++) {
			if((call neighbors.get(keys[i])).confirmedNeighbor == TRUE) {
				printf("%d, ", keys[i]);
			}
		}
		printf("\n");
	}

	command uint8_t* Neighbor.getNeighborArray() {
		int i;
		int y = 0;
		uint32_t *keys = call neighbors.getKeys();
		for(i = 0; i < call neighbors.size(); i++) {
			if((call neighbors.get(keys[i])).confirmedNeighbor == TRUE) {
				finalizedNeighbors[y] = (call neighbors.get(keys[i])).node;
				y++;
			}
		}
		return finalizedNeighbors;
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