#include "../../includes/packet.h"

module LinkStateP {
	provides interface LinkState;
	uses interface SimpleSend;
	uses interface Flooding;
	uses interface Timer<TMilli> as myTimer;
	uses interface List<neighborPair> as confirmed;
    uses interface List<neighborPair> as tentative;
}

implementation {
    // this will store sequence number of latest LSP recieved at each node's index
    int cache[20];
    int neighborMatrix[20][20] = {0};

/*  1. gets list of nodes neighbors, check the cache to see if we already have it
    2. if we do, then exit and disregard
    3. if we dont, when lsp comes turn on the timer 
    4. if another lsp comes, restart the timer 
    5. if timer expires, then that means we have all the lsps
    6. lsps have been added to a matrix - no parsing yet
    7. when timer expires, then we run SP
    8. Neighbor Module: when neighbors have settled, send neighbors to LinkState module 
    9. add your own neighbors to the neighbor matrix
    10. put self w weight 0 to tentative list. then start loop
    11. loop is, call func to find item with lowest weight
    12. put that item on the confirmed list.
    13. then, get the list of neighbors for that chosen node
    14. parse those neighbors into the tentative list with weight = the nodes weight + 1
    14a. as part of parse func, check each item to the tentative list. if the same node is already on it, 
        replace if weight is higher, skip of weight is lower
    15. repeat loop 
    16. if tentative list is empty, then return
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
        int b = 0;
        int a[12];
        for(i = 0; i <= 12; i++) {
            if(neighborMatrix[i][0] != 0) {
                a[b] = i + 1;
                b++;
                tot++;
            }
        }
       // dbg(GENERAL_CHANNEL, "I have recieved Lsps from %d nodes. top 4 are %d, %d, %d, %d, %d, %d, %d, %d, %d\n", tot, a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8]);
    }
}