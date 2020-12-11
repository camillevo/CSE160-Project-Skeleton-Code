#include "../../includes/packet.h"

interface Application{
    command uint8_t read(socket_store_t *mySocket, char* messsage);
}