interface CommandHandler{
   // Events
   event void ping(uint16_t destination, uint8_t *payload);
   event void printNeighbors();
   event void printRouteTable();
   event void printLinkState();
   event void printDistanceVector();
   event void setTestServer(int port);
   event void setTestClient(int destination, int sourcePort, int destPort, int transfer);
   event void setClientClose(int dest, int srcPort, int destPort);
   event void setAppServer(int port, uint8_t *msg);
   event void setAppClient(int port, uint8_t *msg);
}
