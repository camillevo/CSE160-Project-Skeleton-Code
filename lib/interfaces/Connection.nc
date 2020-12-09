#include "../../includes/packet.h"

interface Connection{
    command void testServer(int port);
    command void testClientBytes(int destination, int sourcePort, int destPort, int transfer);
    command void testClientString(int destination, int sourcePort, int destPort, uint8_t *transfer);
    command error_t sendMsg(int destination, int sourcePort, int destPort, uint8_t *transfer);
    command void clientClose(int dest, int srcPort, int destPort);
}