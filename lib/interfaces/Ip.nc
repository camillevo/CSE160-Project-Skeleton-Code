#include "../../includes/packet.h"

interface Ip{
  //all commands which are provided to other files by the module must be listed here. Similarly to the implementation of a .h file
  command void ping(pack sendPacket);
}