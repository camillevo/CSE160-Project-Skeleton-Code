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
    uses interface Timer<TMilli> as connectTimer;
    uses interface Timer<TMilli> as acceptTimer;

    uses interface Neighbor;
    uses interface LinkState;
    uses interface Ip;
    uses interface Transport;
}

implementation{
	pack sendPackage;
	int seqNum = 0;
	int * sequenceNum = &seqNum;
    int messageCache[5][2] = {{0}};

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
		
		//call LinkState.printRoutingTable();
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
        int i;
        socket_t mySocketFD = call Transport.socket();
        socket_addr_t myAddress = {.port = (nx_uint8_t) port, .addr = (nx_uint16_t) TOS_NODE_ID};

        call Transport.bind(mySocketFD, &myAddress);
        call Transport.listen(mySocketFD);

        for(i = 0; i < 5; i++) {
            if(messageCache[i][0] == 0) {
                // For servers, 0 is for listening sockets, 1 for accepted.
                messageCache[i][0] = (int) mySocketFD;
                break;
            }
        }

        call acceptTimer.startOneShot(15968);
	}

    event void Transport.connectionReady(uint8_t clientPort, uint16_t server, uint8_t serverPort, uint16_t sequence, uint16_t ack) {
        // no longer using. Delete at end of project.
    }

	event void CommandHandler.setTestClient(int destination, int sourcePort, int destPort, int transfer){
        int i = 0;
        socket_t mySocketFD = call Transport.socket();
        socket_addr_t myAddress = {.port = (nx_uint8_t) sourcePort};
        socket_addr_t destAddress = {.port = (nx_uint8_t) destPort};
        destAddress.addr = (nx_uint16_t) destination;
        myAddress.addr = (nx_uint16_t) TOS_NODE_ID; 
       
        call Transport.bind(mySocketFD, &myAddress);

        // Add fd and message to cache
        for(i = 0; i < 5; i++) {
            if(messageCache[i][0] == 0) {
                messageCache[i][0] = (int) mySocketFD;
                messageCache[i][1] = transfer;
                break;
            }
        }

        call Transport.connect(mySocketFD, &destAddress);

        call connectTimer.startOneShot(15968);
	}

    event void connectTimer.fired() {
        // do nothing for now
    }

    event void acceptTimer.fired() {
        int i, j;
        //dbg(TRANSPORT_CHANNEL, "starting accept\n");
        for(i = 0; i < 5; i++) {
            if(messageCache[i][0] == 0) break;
            if(messageCache[i][1] == 0) {
                //printf("about to call accept\n");
                socket_t curr = call Transport.accept(messageCache[i][0]);
                if(curr == 0) {
                    call acceptTimer.startOneShot(15968);
                    return;
                } else {
                    for(j = i; j < 5; j++) {
                        if(messageCache[j][0] == 0) {
                            messageCache[j][0] = curr;
                            messageCache[j][1] = 1;
                            printf("added newly made socket to my array\n");
                            break;
                        }
                    }
                }
            }

        }
        return;
    }

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
