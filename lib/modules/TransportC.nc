#include "../../includes/socket.h"

configuration TransportC{
  provides interface Transport;
}
implementation{
  components TransportP;
  Transport = TransportP.Transport;

  components new HashmapC(socket_store_t, 10) as SampleMap;
  TransportP.sockets -> SampleMap;

//   components new HashmapC(char[20], 10) as myMap;
//   TransportP.users -> myMap;

  components new ListC(connection, 10) as SampleList;
  TransportP.attemptedConnections -> SampleList;
 
  components new TimerMilliC() as myTimerA; //create a new timer with alias “myTimerC”
  TransportP.resendTimer -> myTimerA;

  components new TimerMilliC() as myTimerB; //create a new timer with alias “myTimerC”
  TransportP.synTimer -> myTimerB;

  components new TimerMilliC() as myTimerC; //create a new timer with alias “myTimerC”
  TransportP.synackTimer -> myTimerC;

  components RandomC;
  TransportP.Random -> RandomC;

  components ApplicationC;
  TransportP.Application -> ApplicationC;

  components IpC;
  TransportP.Ip -> IpC;
}
