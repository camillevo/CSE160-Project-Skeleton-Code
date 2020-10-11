#include "../../includes/packet.h"

module LinkStateP {
	provides interface LinkState;
	uses interface SimpleSend;
	uses interface Flooding;
	uses interface Timer<TMilli> as myTimer;
	uses interface Hashmap<neighborPair> as confirmed;
    uses interface Hashmap<neighborPair> as tentative;
}

implementation {
    // this will store sequence number of latest LSP recieved at each node's index
    int cache[20];
    int neighborMatrix[20][20] = {0};

/*  1. gets list of nodes neighbors, check the cache to see if we already have it
    2. if we do, then exit and disregard

    7. when timer expires, then we run SP
*/

    command void LinkState.addLsp(pack *lsp) {
        memcpy(neighborMatrix[lsp->src - 1], lsp->payload, sizeof(int) * 20);
       // dbg(GENERAL_CHANNEL, "added lsp from %d to neighbor matrix\n", lsp->src);
        
        call Flooding.floodSend(*lsp, TOS_NODE_ID, TOS_NODE_ID);
        // Start a new timer - if no new LSP's come before expiring, then LSPs have settled
        call myTimer.startOneShot(300000);
    }
    event void myTimer.fired() {
        int i;
        int tot = 0;
        int a[12];
        for(i = 0; i <= 12; i++) {
            if(neighborMatrix[i][0] != 0) {
                a[tot] = i + 1;
                tot++;
            }
        }
        if(tot != 9) {
            call myTimer.startOneShot(10000);
            return;
        }
        //dbg(GENERAL_CHANNEL, "Recieved Lsps from %d nodes: %d, %d, %d, %d, %d, %d, %d, %d, %d\n", tot, a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8]);
        call LinkState.findShortestPath();
    }

    command void LinkState.findShortestPath() {
        neighborPair self;
        self.node = TOS_NODE_ID;
        self.weight = 0;
        self.nextHop = TOS_NODE_ID;
        self.backupNextHop = 0;
        self.backupWeight = 100;

        call tentative.insert(TOS_NODE_ID, self);
        while(!call tentative.isEmpty()) {
            call LinkState.dijkstraLoop();
        }
        call LinkState.printRoutingTable();
    }

    command void LinkState.dijkstraLoop() {
        int curr = call LinkState.findSmallestWeight();
        neighborPair currNode = call tentative.get(curr);
        int i;
        call confirmed.insert(curr, currNode);
        call tentative.remove(curr);

        for(i = 0; i < 10; i++) {
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

    command int LinkState.findSmallestWeight() {
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
        printf(" Node | Weight | NextHop | Backup | Backup Weight\n");
        printf("--------------------------------------------------\n");

        for(i = 0; i < call confirmed.size(); i++) {
            neighborPair current = call confirmed.get(keys[i]);
            printf("  %d   |   %d    |    %d    |", current.node, current.weight, current.nextHop);
            if(current.backupWeight != 100) {
                printf("   %d    |   %d\n", current.backupNextHop, current.backupWeight);
            } else {
                printf("   -    |   -\n");
            }
        }
    }
}