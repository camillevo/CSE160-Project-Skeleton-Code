#include "../../includes/packet.h"

interface Neighbor{
   // Events
   command void startNeighborDiscovery();
   command error_t sendPackets();
   command bool detectChange();
   command void generateLSP();
   command bool findNeighbor(int x);
   command void printNeighbors();
   command int* getNeighborArray();
}
