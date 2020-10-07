interface Neighbor{
   // Events
   command void startNeighborDiscovery();
   command error_t sendPackets();
   // command error_t testHashmap();
   command bool findNeighbor(int x);
   command void printNeighbors();
   command int* getNeighborArray();
}
