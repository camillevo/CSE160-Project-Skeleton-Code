#include "../../includes/packet.h"

interface Connection{
    command void testServer(int port);
    command void testClient(int destination, int sourcePort, int destPort, int transfer);
    command void clientClose(int dest, int srcPort, int destPort);
}