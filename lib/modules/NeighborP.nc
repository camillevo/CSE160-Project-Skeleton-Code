#include "../../includes/packet.h"

module NeighborP {
	provides interface Neighbor;
	uses interface SimpleSend;
	//uses interface HashMap<integer> as neighbors;
	uses interface Random;
	uses interface Timer<TMilli> as periodicTimerA; //Interface that was wired
	uses interface Timer<TMilli> as periodicTimerB;
}

implementation {
	int neighbors[20] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
	int sequenceNum = 0;
	bool neighborsHaveSettled = 1;
	void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

	/*
	command error_t Neighbor.testHashmap() {
		call neighbors.insert(1, sample);
		call neighbors.insert(5, sample);
		
		keys = call neighbors.getKeys();
		
		dbg(GENERAL_CHANNEL, "keys %d\n", *keys);
	}*/
	
	command error_t Neighbor.sendPackets(){
		pack neighborDiscoveryPacket;
		char neighborMessage[] = "ND";

		makePack(&neighborDiscoveryPacket, TOS_NODE_ID, AM_BROADCAST_ADDR, 2, PROTOCOL_NEIGHBORDISCOVERY, *(&sequenceNum), neighborMessage, PACKET_MAX_PAYLOAD_SIZE);

		call SimpleSend.send(neighborDiscoveryPacket, AM_BROADCAST_ADDR);
	}

	command void Neighbor.startNeighborDiscovery() {
		call periodicTimerA.startPeriodic(900000);
		call periodicTimerB.startPeriodic(3000);
		call Neighbor.sendPackets();
		*(&sequenceNum) = sequenceNum + 1;
	}

	event void periodicTimerA.fired() {
		*(&sequenceNum) = sequenceNum + 1;
		call Neighbor.sendPackets();
	}

	event void periodicTimerB.fired() {
		if (neighborsHaveSettled == 0) {
			*(&neighborsHaveSettled) = 1;
			call Neighbor.printNeighbors();

			// Call flooding for LSP's
		}
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
		//dbg(GENERAL_CHANNEL, "found neighbor %d. neighbors are now [%d, %d, %d, %d, %d, %d]\n", x, neighbors[0], neighbors[1], neighbors[2], neighbors[3], neighbors[4], neighbors[5], neighbors[6]);
		
		return ret;
	}
	
	command void Neighbor.printNeighbors() {
		dbg(GENERAL_CHANNEL, "%d has neighbors %d, %d, %d, %d, %d, %d, %d, %d\n", TOS_NODE_ID, neighbors[0], neighbors[1], neighbors[2], neighbors[3], neighbors[4], neighbors[5], neighbors[6], neighbors[7], neighbors[8]);
	}
	
	command int * Neighbor.getNeighborArray() {
		return neighbors;
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