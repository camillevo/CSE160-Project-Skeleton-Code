#include "../../includes/packet.h"

interface LinkState{
    command void addLsp(pack *lsp);
    command void findShortestPath();
    command void dijkstraLoop();
    command int findSmallestWeight();
    command void printRoutingTable();
}
