#include "../../includes/packet.h"

module LinkStateP {
	provides interface LinkState;
	uses interface Flooding;
    uses interface Neighbor;
	uses interface Timer<TMilli> as myTimer;
	uses interface Hashmap<neighborPair> as confirmed;
    uses interface Hashmap<neighborPair> as tentative;
}

implementation {
    int sequenceNum = 1;
    int seqNumCache[30] = {0};
    uint8_t neighborMatrix[30][30] = {{0}};

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
    void findShortestPath();
    void dijkstraLoop();
    int findSmallestWeight();

    event void Neighbor.neighborsHaveSettled() {
        pack myPack;
        uint8_t *neighbors = call Neighbor.getNeighborArray();
        //dbg(GENERAL_CHANNEL, "Neighbors: %d, %d\n", neighbors[0], neighbors[1]);
        makePack(&myPack, TOS_NODE_ID, 0, 20, PROTOCOL_LINKSTATE, sequenceNum, neighbors, PACKET_MAX_PAYLOAD_SIZE);
        call LinkState.addLsp(&myPack);
        *(&sequenceNum) = sequenceNum + 1;
	}

    command void LinkState.addLsp(pack *lsp) {
        if(seqNumCache[lsp->src] >= lsp->seq) {
            return;
        } else {
            seqNumCache[lsp->src] = lsp->seq;
        }
        memcpy(neighborMatrix[lsp->src - 1], lsp->payload, sizeof(uint8_t) * 30);
        call Flooding.floodSend(*lsp, lsp->src, 0);
        // Start a new timer - if no new LSP's come before expiring, then LSPs have settled
        call myTimer.startOneShot(501948);
    }

    event void myTimer.fired() {
        //int i;
        // empty confirmed list before calling findShortestPath();
        call confirmed.clear();
        // if(TOS_NODE_ID < 10) {
        //     dbg(GENERAL_CHANNEL, " Got LSPs from ");
        // } else {
        //     dbg(GENERAL_CHANNEL, "Got LSPs from ");
        // }
        // for(i = 1; i <= 30; i++) {
        //     if(neighborMatrix[i - 1][0] != 0) {
        //         printf("%d, ", i);
        //     } else {
        //         printf("--, ");
        //     }
        // }
        // printf("\n");
        findShortestPath();
    }
    
    void findShortestPath() {
        neighborPair self;
        self.node = TOS_NODE_ID;
        self.weight = 0;
        self.nextHop = TOS_NODE_ID;
        self.backupNextHop = 0;
        self.backupWeight = 100;

        call tentative.insert(TOS_NODE_ID, self);
        while(!call tentative.isEmpty()) {
            dijkstraLoop();
        }

        //call LinkState.printRoutingTable();
        signal LinkState.routingTableReady();
    }

    void dijkstraLoop() {
        int curr = findSmallestWeight();
        neighborPair currNode = call tentative.get(curr);
        int i;

        call confirmed.insert(curr, currNode);
        call tentative.remove(curr);

        for(i = 0; i < 30; i++) {
            neighborPair currNeighbor;
            if(neighborMatrix[curr - 1][i] == 0) {
                break;
            }
            currNeighbor.weight = (call confirmed.get(curr)).weight + 1;
            currNeighbor.node = neighborMatrix[curr - 1][i];
            currNeighbor.backupNextHop = 0;
            currNeighbor.backupWeight = 100;

            if(curr == TOS_NODE_ID) {
                currNeighbor.nextHop = currNeighbor.node;
            } else {
                currNeighbor.nextHop = currNode.nextHop;
            }

            if(call confirmed.contains(currNeighbor.node)) {
                neighborPair *existingSP = call confirmed.getPointer(currNeighbor.node);
                if((existingSP->node != TOS_NODE_ID) && (existingSP->nextHop != currNeighbor.nextHop) && (existingSP->backupWeight > currNeighbor.weight)) {
                    existingSP->backupNextHop = currNeighbor.nextHop;
                    existingSP->backupWeight = currNeighbor.weight;
                }
                continue;
            }

            if(call tentative.contains(currNeighbor.node)) {
                neighborPair *existingSP = call tentative.getPointer(currNeighbor.node);
                if(existingSP->weight > currNeighbor.weight) {
                    if(existingSP->nextHop != currNeighbor.nextHop) {
                        currNeighbor.backupNextHop = existingSP->nextHop;
                        currNeighbor.backupWeight = existingSP->weight;
                    }
                    call tentative.remove(curr);
                } else {
                    if(existingSP->nextHop != currNeighbor.nextHop) {
                        existingSP->backupNextHop = currNeighbor.nextHop;
                        existingSP->backupWeight = currNeighbor.weight;
                    }
                    continue;
                }
            }
            call tentative.insert(currNeighbor.node, currNeighbor);
        }
    }

    int findSmallestWeight() {
        uint16_t i;
        int min = 100;
        int node;
        uint32_t* keys = call tentative.getKeys();
        
        for(i = 0; i < call tentative.size(); i++) {
            int currWeight = (call tentative.get(keys[i])).weight;
            if(currWeight < min) {
                min = currWeight;
                node = keys[i];
            }
        }
        return node;
    }

    command void LinkState.printRoutingTable() {
        uint32_t* keys = call confirmed.getKeys();
        int i;
        
        dbg(GENERAL_CHANNEL, "Routing table for %d complete\n", TOS_NODE_ID);
        printf(" Node | NextHop | Weight | Backup | Backup Weight\n");
        printf("--------------------------------------------------\n");

        for(i = 0; i < call confirmed.size(); i++) {
            neighborPair current = call confirmed.get(keys[i]);
            printf(" %2d   |   %2d    |   %d    |", current.node, current.nextHop, current.weight);
            if(current.backupWeight != 100) {
                printf("  %2d    |   %d\n", current.backupNextHop, current.backupWeight);
            } else {
                printf("   -    |   -\n");
            }
        }
    }

    command void LinkState.printLSPs() {
        int i;
        printf("Recieved LSP's for node %d\n", TOS_NODE_ID);
        for(i = 0; i < 30; i++) {
            int y;
            if(neighborMatrix[i][0] != 0) printf("%d: %d", i, neighborMatrix[i][0]);
            for(y = 1; y < 30; y++) {
                if(neighborMatrix[i][y] == 0) {
                    break;
                }
                printf(", %d", neighborMatrix[i][y]);
            }
            printf("\n");
        }
    }

    command int LinkState.getNextHop(int node) {
        return (call confirmed.get(node)).nextHop;
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