interface CommandHandler{
   // Events
   event void ping(uint16_t destination, uint8_t *payload);
   event void printNeighbors();
   event void printRouteTable();
   event void printLinkState();
   event void printDistanceVector();
   event void setTestServer(int port);
   event void setTestClient(int destination, int sourcePort, int destPort, int transfer);
   event void setAppServer();
   event void setAppClient();
}
