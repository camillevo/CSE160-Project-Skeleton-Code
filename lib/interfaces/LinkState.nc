#include "../../includes/packet.h"

interface LinkState{
    command void addLsp(pack *lsPack);
    //command void findShortestPath();
    //command void dijkstraLoop();
    //command int findSmallestWeight();
    command void printRoutingTable();
    //command void nodeDown(uint8_t node);
    command int getNextHop(int node);
    //command int getBackupNextHop(int node);
    event void routingTableReady();

}
