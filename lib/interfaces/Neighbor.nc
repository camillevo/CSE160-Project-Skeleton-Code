interface Neighbor{
   // Events
   command error_t sendPackets(pack x);
   // command error_t testHashmap();
   command bool findNeighbor(int x);
   command void printNeighbors();
   command int getNeighborArray();
   command bool checkCache(int src, int seqNum);
command void floodSend(pack x, uint16_t from, uint16_t destination, uint8_t* payload); 
}
