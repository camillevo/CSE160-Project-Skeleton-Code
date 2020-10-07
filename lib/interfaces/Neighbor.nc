interface Neighbor{
   // Events
   command error_t sendPackets(pack x);
   // command error_t testHashmap();
   command bool findNeighbor(int x);
   command void printNeighbors();
   command int* getNeighborArray();
}
