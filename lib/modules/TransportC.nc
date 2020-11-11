#include "../../includes/socket.h"

configuration TransportC{
  provides interface Transport;
}
implementation{
  components TransportP;
  Transport = TransportP.Transport;

  components new HashmapC(socket_store_t, 10) as SampleMap;
  TransportP.sockets -> SampleMap;

  components RandomC;
  TransportP.Random -> RandomC;
}
