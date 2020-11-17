#include "../../includes/socket.h"

configuration TransportC{
  provides interface Transport;
}
implementation{
  components TransportP;
  Transport = TransportP.Transport;

  components new HashmapC(socket_store_t, 10) as SampleMap;
  TransportP.sockets -> SampleMap;

  components new ListC(connection, 10) as SampleList;
  TransportP.attemptedConnections -> SampleList;

  components RandomC;
  TransportP.Random -> RandomC;

  components IpC;
  TransportP.Ip -> IpC;
}
