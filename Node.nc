/*
* ANDES Lab - University of California, Merced
* This class provides the basic functions of a network node.
*
* @author UCM ANDES Lab
* @date   2013/09/03
*
*/
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include "includes/socket.h"

module Node{
    uses interface Boot;

    uses interface SplitControl as AMControl;
    uses interface CommandHandler;
    //uses interface Timer<TMilli> as connectTimer;
    //uses interface Timer<TMilli> as acceptTimer;

    uses interface Neighbor;
    uses interface LinkState;
    uses interface Ip;
    uses interface Transport;
    uses interface Connection;
}

implementation{
	pack sendPackage;
	int seqNum = 0;
	int * sequenceNum = &seqNum;

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

	event void Boot.booted(){
		call AMControl.start();
		call Neighbor.startNeighborDiscovery();
        
		dbg(GENERAL_CHANNEL, "Booted\n");
	}

	event void AMControl.startDone(error_t err){
		if(err == SUCCESS){
		 dbg(GENERAL_CHANNEL, "Radio On\n");
		}else{
		 //Retry until successful
		 call AMControl.start();
		}
	}

    event void AMControl.stopDone(error_t err){}


	event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
		*(&sequenceNum) = sequenceNum + 1;
	
		dbg(GENERAL_CHANNEL, "PING EVENT \n");
		makePack(&sendPackage, TOS_NODE_ID, destination, 5, PROTOCOL_PING, seqNum, payload, PACKET_MAX_PAYLOAD_SIZE);
		
		call Ip.ping(sendPackage);
	}

	event void Neighbor.neighborsHaveSettled(){}
	event void LinkState.routingTableReady(){}

	event void CommandHandler.printNeighbors(){
		call Neighbor.printNeighbors();
	}

	event void CommandHandler.printRouteTable(){
		call LinkState.printRoutingTable();
	}

	event void CommandHandler.printLinkState(){
		call LinkState.printLSPs();
		call LinkState.printRoutingTable();
	}

	event void CommandHandler.printDistanceVector(){}

	event void CommandHandler.setTestServer(int port){
        call Connection.testServer(port);
	}

	event void CommandHandler.setTestClient(int destination, int sourcePort, int destPort, int transfer){
        call Connection.testClient(destination, sourcePort, destPort, transfer);
	}

    event void CommandHandler.setClientClose(int dest, int srcPort, int destPort){
        call Connection.clientClose(dest, srcPort, destPort);
    }

	event void CommandHandler.setAppServer(){}

	event void CommandHandler.setAppClient(int port, uint8_t *username){
        dbg(TRANSPORT_CHANNEL, "Will setup connection on %d:%d as user %s\n", TOS_NODE_ID, port, username);
    }

	void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
		Package->src = src;
		Package->dest = dest;
		Package->TTL = TTL;
		Package->seq = seq;
		Package->protocol = protocol;
		memcpy(Package->payload, payload, length);
	} 
}
