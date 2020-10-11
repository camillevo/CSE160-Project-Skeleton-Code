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

module Node{
   uses interface Boot;
   //uses interface Timer<TMilli> as periodicTimer; //Interface that was wired

   uses interface SplitControl as AMControl;
   uses interface Receive;

   uses interface sampleModule as sampleMod;
   uses interface SimpleSend as Sender;

   uses interface CommandHandler;
   
   uses interface Neighbor;
   uses interface Flooding;
   uses interface LinkState;
}

implementation{

   pack sendPackage;
   int sequenceNum = 0;

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

	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
		if(len==sizeof(pack)){
			pack* myMsg=(pack*) payload;
			
			if(myMsg->dest == AM_BROADCAST_ADDR) {
				uint8_t none = 0;
				// check if neighbor discovery packet
				// return neighbor response
				makePack(&sendPackage, TOS_NODE_ID, myMsg->src, 3, PROTOCOL_NEIGHBORRESPONSE, sequenceNum, &none, PACKET_MAX_PAYLOAD_SIZE);
				call Sender.send(sendPackage, myMsg->src);
				return msg;
			}
			
			if(myMsg->protocol == PROTOCOL_NEIGHBORRESPONSE) {				
				call Neighbor.findNeighbor(myMsg->src);
				
				return msg;
			}

			if(myMsg->protocol == PROTOCOL_LSP) {
				if(myMsg->dest == TOS_NODE_ID) {
					return msg;
				}
				call LinkState.addLsp(myMsg);

				return msg;
			}
			
			if(myMsg->dest != TOS_NODE_ID) {
				makePack(&sendPackage, myMsg->src, myMsg->dest, (myMsg->TTL) - 1, PROTOCOL_PING, myMsg->seq, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
				call Flooding.floodSend(sendPackage, myMsg->src, myMsg->dest);
				return msg;
			}
			
			dbg(GENERAL_CHANNEL, "Packet Received\n");
			
			dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
			return msg;
		}
		dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
		return msg;
	}


	event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
		*(&sequenceNum) = sequenceNum + 1;
	
		dbg(GENERAL_CHANNEL, "PING EVENT \n");
		makePack(&sendPackage, TOS_NODE_ID, destination, 5, PROTOCOL_PING, sequenceNum, payload, PACKET_MAX_PAYLOAD_SIZE);
		
		call Flooding.floodSend(sendPackage, TOS_NODE_ID, destination);
	}

	event void CommandHandler.printNeighbors(){}

	event void CommandHandler.printRouteTable(){}

	event void CommandHandler.printLinkState(){}

	event void CommandHandler.printDistanceVector(){}

	event void CommandHandler.setTestServer(){}

	event void CommandHandler.setTestClient(){}

	event void CommandHandler.setAppServer(){}

	event void CommandHandler.setAppClient(){}

	void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
		Package->src = src;
		Package->dest = dest;
		Package->TTL = TTL;
		Package->seq = seq;
		Package->protocol = protocol;
		memcpy(Package->payload, payload, length);
	}
}
