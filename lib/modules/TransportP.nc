#include "../../includes/packet.h"
#include "../../includes/socket.h"

module TransportP{
  provides interface Transport;

  uses interface Hashmap<socket_store_t> as sockets;
  //uses interface Hashmap<char[20]> as users;
  uses interface List<connection> as attemptedConnections;
  uses interface Timer<TMilli> as resendTimer;
  uses interface Timer<TMilli> as synTimer;
  uses interface Timer<TMilli> as synackTimer;
  uses interface Random;
  uses interface Application;
  uses interface Ip;
}

implementation{
    pack sendPackage;
    tcpHeader sendTcpHeader;
    uint8_t cmdMessage[20]; 

    
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
    void makeTcpHeader(tcpHeader *myHeader, uint8_t sourcePort, uint8_t destPort, uint16_t sequence, uint16_t ack, enum flags flag, uint16_t advertisedWindow);
    //socket_t findSocket(uint16_t server, uint8_t serverPort, uint8_t clientPort) {
    int findCommand(uint8_t *cmdString);

    command socket_t Transport.socket() {
        if(call sockets.size() < 10) {
            return( (socket_t) call Random.rand16() % 255);
        } else {
            return (socket_t) 0;
        }
    }

    command error_t Transport.bind(socket_t fd, socket_addr_t *addr){
        if(call sockets.contains((uint32_t) fd) == FALSE) {
            socket_store_t mySocket;
            mySocket.src = *addr;  
            mySocket.state = CLOSED;
            call sockets.insert((uint32_t) fd, mySocket);
            return SUCCESS;
        }
        return FAIL;
    }

    command socket_t Transport.accept(socket_t fd){
        socket_store_t *currSocket = call sockets.getPointer(fd);
        socket_t newFD;
        //socket_store_t *newSocket = malloc(sizeof(socket));
        socket_store_t newSocket;

        int i;
        connection curr;
        currSocket->state = LISTEN;
        for(i = call attemptedConnections.size(); i >= 0; i--) {
            if(i == 0) return (uint8_t) 0;
            
            curr = call attemptedConnections.popfront();
            // Can only accept 1 conenction per accept(), so break;
            if(currSocket->state == LISTEN && curr.serverPort == currSocket->src.port) break;
            else call attemptedConnections.pushback(curr);
        }

        // Make a new connection
        newFD = call Transport.socket();
        newSocket.state = ESTABLISHED;
        newSocket.src.addr = TOS_NODE_ID;
        newSocket.src.port = curr.serverPort;
        newSocket.dest.port = curr.clientPort;
        newSocket.dest.addr = curr.clientNode;
        newSocket.lastWritten = curr.mySeqNum + 1;
        newSocket.lastSent = curr.mySeqNum;
        newSocket.lastAck = curr.mySeqNum + 1;
        newSocket.lastAckIndex = 0;
        newSocket.lastRead = curr.seqNum;
        newSocket.lastRcvd = curr.seqNum;
        newSocket.lastReadIndex = 0;
        // newSocket.username = malloc(20);
        newSocket.nextExpected = curr.seqNum + 1;
        newSocket.effectiveWindow = TCP_MAX_DATA * 3;

        call sockets.insert(newFD, newSocket);

        dbg(TRANSPORT_CHANNEL, "Accepted connection on port %d from Node %d, port %d. seqnum = %d\n", 
            newSocket.src.port, newSocket.dest.addr, newSocket.dest.port, newSocket.lastSent);
        return newFD;
    }

    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen) {
        socket_store_t *mySocket = call sockets.getPointer(fd);
        uint8_t currIndex = (uint8_t) (mySocket->lastWritten - mySocket->lastAck + mySocket->lastAckIndex);
        uint16_t min;
        if(mySocket->state != ESTABLISHED) {
            return 0;
        }
        // If there's not enough room in the socket for bufflen
        if(mySocket->lastAckIndex > 0 && SOCKET_BUFFER_SIZE - currIndex < bufflen) {
            //dbg(TRANSPORT_CHANNEL, "Removed %d ACKed bytes\n", currIndex);
            // If more room is needed & available, remove already ACKed bytes
            currIndex = (uint8_t) (mySocket->lastWritten - mySocket->lastAck);
            memcpy(&(mySocket->sendBuff[0]), &(mySocket->sendBuff[mySocket->lastAckIndex + 1]), currIndex);
            mySocket->lastAckIndex = 0;
        }
        min = (bufflen < (SOCKET_BUFFER_SIZE - currIndex) ? bufflen : SOCKET_BUFFER_SIZE - currIndex);

        //dbg(TRANSPORT_CHANNEL, "Wrote %s at index %d\n", min, currIndex);
                       
        memcpy(&(mySocket->sendBuff[currIndex]), buff, SOCKET_BUFFER_SIZE - currIndex);
        mySocket->lastWritten = mySocket->lastWritten + min;
        dbg(TRANSPORT_CHANNEL, "Sending to %d:%d\n", mySocket->dest.addr, mySocket->dest.port);
        call Transport.sendBuffer(mySocket);

        return min;
    }

    command void Transport.writeAll(char* message) {
        uint32_t *keys = call sockets.getKeys();
        uint8_t i;
        for(i = 0; i < call sockets.size(); i++) {
            socket_store_t curr = call sockets.get(keys[i]);
            if(curr.state == ESTABLISHED) {
                call Transport.write(keys[i], (uint8_t *)message, strlen(message) + 1);
            }
        }
    }

    command void Transport.sendBuffer(socket_store_t *mySocket) {
        if(mySocket->state != ESTABLISHED) {
            dbg(TRANSPORT_CHANNEL, "Socket on port %d is not yet established.\n", mySocket->src.addr);
            return;
        }
        while(mySocket->effectiveWindow > 0) {
            // Find min of effectiveWindow, lastWritten, and TCP_MAX_DATA
            uint8_t bytesToSend = (uint8_t)(mySocket->lastWritten - mySocket->lastSent - 1) > TCP_MAX_DATA ? TCP_MAX_DATA : (uint8_t)(mySocket->lastWritten - mySocket->lastSent - 1);
            if(mySocket->effectiveWindow < bytesToSend) bytesToSend = mySocket->effectiveWindow;
            if(bytesToSend == 0) {
                //dbg(TRANSPORT_CHANNEL, "Need more data on port %d!\n", mySocket->src.port);
                return;
            }
            // Repurposing ACK to store length of payload
            makeTcpHeader(
                &sendTcpHeader, mySocket->src.port, mySocket->dest.port, mySocket->lastSent + 1, 
                bytesToSend, NONE, TCP_MAX_DATA * 3
            );
            memcpy((&sendTcpHeader)->payload, &(mySocket->sendBuff[mySocket->lastSent + 1 - mySocket->lastAck + mySocket->lastAckIndex]), bytesToSend);

            makePack(&sendPackage, TOS_NODE_ID, mySocket->dest.addr, call Random.rand16() % 100, PROTOCOL_TCP, 
                sendTcpHeader.sequence, (uint8_t *) &sendTcpHeader, TCP_HEADER_LENGTH + bytesToSend
            );
            //dbg(TRANSPORT_CHANNEL, "Sent bytes %d to %d to port %d\n", mySocket->lastSent + 1, mySocket->lastSent + bytesToSend, mySocket->dest.port);
            call Ip.ping(sendPackage);
            mySocket->lastSent += bytesToSend;
            mySocket->effectiveWindow -= bytesToSend;
        }
        // If there's more to write, then call resend timer.
        // +-1 is wiggle room for my own potential errors in indexing
        if(mySocket->lastSent < mySocket->lastWritten - 1 || mySocket->lastSent > mySocket->lastWritten + 1) {
            //dbg(TRANSPORT_CHANNEL, "restarting timer. lastSent = %d, lastWritten = %d \n", mySocket->lastSent, mySocket->lastWritten);
            call resendTimer.startOneShot(1500);
        } 
    }

    event void resendTimer.fired() {
        // Iterate thru sockets
        uint32_t *keys = call sockets.getKeys();
        int i;
        for(i = call sockets.size() - 1; i >= 0; i--) {
            socket_store_t *mySocket = call sockets.getPointer(keys[i]);
            // Start send from whatever was last ACKed
            if(mySocket->state == ESTABLISHED) {
                mySocket->lastSent = mySocket->lastAck - 1;
                call Transport.sendBuffer(mySocket);
            }
        }
    }

    command error_t Transport.receive(pack* package) {
        tcpHeader *myHeader = package->payload;
        socket_t fd = call Transport.findSocket(myHeader->destPort, package->src, myHeader->sourcePort);
        socket_store_t *mySocket = call sockets.getPointer(fd);

        switch(myHeader->flag) {
            case SYN: {
                connection myConnection;
                myConnection.clientNode = package->src;
                myConnection.clientPort = myHeader->sourcePort;
                myConnection.seqNum = myHeader->sequence;
                myConnection.serverPort = myHeader->destPort;
                myConnection.mySeqNum = call Random.rand16() % 256;
                call attemptedConnections.pushfront(myConnection);
                //dbg(TRANSPORT_CHANNEL, "SYN received from Node %d, port %d\n", package->src, myHeader->sourcePort);

                mySocket->state = SYN_RCVD;

                makeTcpHeader(
                    &sendTcpHeader, myHeader->destPort, myConnection.clientPort, myConnection.mySeqNum, 
                    myConnection.seqNum + 1, SYNACK, TCP_MAX_DATA * 3
                );
                makePack(&sendPackage, TOS_NODE_ID, myConnection.clientNode, call Random.rand16() % 100, PROTOCOL_TCP, sendTcpHeader.sequence, (uint8_t *) &sendTcpHeader, PACKET_MAX_PAYLOAD_SIZE);
                call Ip.ping(sendPackage);
                
                //call synackTimer.startOneShot(1200);
                return SUCCESS;
            }
            break;
            case SYNACK: {
                //dbg(TRANSPORT_CHANNEL, "SYNACK received from Node %d, port %d\n", package->src, myHeader->sourcePort);

                // check if ack is the same as the sequence I sent
                if(myHeader->ack != mySocket->lastSent + 1) {
                    return FAIL;
                }
                if(call synTimer.isRunning()) call synTimer.stop();

                mySocket->nextExpected = myHeader->sequence + 1;
                mySocket->lastRcvd = myHeader->sequence;
                mySocket->lastRead = myHeader->sequence;
                mySocket->lastReadIndex = 0;
                mySocket->lastAck = myHeader->ack;
                mySocket->lastWritten = mySocket->lastAck;
                mySocket->state = ESTABLISHED;
                mySocket->effectiveWindow = myHeader->advertisedWindow;
                dbg(TRANSPORT_CHANNEL, "Connection is established! Will start sending data with seq = %d\n", myHeader->ack);
                // Do ACKs have sequences? For now I am assuming they don't????
                makeTcpHeader(&sendTcpHeader, myHeader->destPort, myHeader->sourcePort, 3, myHeader->sequence + 1, ACK, TCP_MAX_DATA * 3);
                makePack(&sendPackage, TOS_NODE_ID, package->src, 20, PROTOCOL_TCP, sendTcpHeader.sequence, (uint8_t *) &sendTcpHeader, PACKET_MAX_PAYLOAD_SIZE);
                call Ip.ping(sendPackage);
                return SUCCESS;
            }
            break;
            case FIN: {
                // Send ACK
                makeTcpHeader(&sendTcpHeader, myHeader->destPort, myHeader->sourcePort, 0, mySocket->nextExpected, ACK, mySocket->effectiveWindow);
                makePack(&sendPackage, TOS_NODE_ID, package->src, 20, PROTOCOL_TCP, myHeader->sequence + 18, (uint8_t *) &sendTcpHeader, PACKET_MAX_PAYLOAD_SIZE);
                call Ip.ping(sendPackage);

                if(mySocket->state != CLOSED) {
                    call Transport.close(fd);
                }
            }
            case ACK: {
                if(fd == 0 || mySocket->state != ESTABLISHED) return FAIL;
                if(call synackTimer.isRunning()) call synackTimer.stop();

                mySocket->lastAckIndex += myHeader->ack - mySocket->lastAck;
                mySocket->lastAck = myHeader->ack;
                mySocket->effectiveWindow = myHeader->advertisedWindow - (mySocket->lastSent - mySocket->lastAck + 1);

                //dbg(TRANSPORT_CHANNEL, "ACK: %d received from %d:%d. effWindow now = %d\n", myHeader->ack, package->src, myHeader->sourcePort, mySocket->effectiveWindow);
            }
            break;
            default: {
                uint8_t TEMP;
                if(myHeader->sequence <= mySocket->nextExpected || myHeader->sequence + myHeader->ack <= mySocket->nextExpected) {
                    // ack field is repurposed as size on client side
                    mySocket->nextExpected = myHeader->sequence + myHeader->ack;
                    mySocket->lastRcvd = myHeader->sequence + myHeader->ack - 1;
                    
                    memcpy(&(mySocket->rcvdBuff[(uint8_t)(myHeader->sequence - mySocket->lastRead - 1 + mySocket->lastReadIndex)]), myHeader->payload, TCP_MAX_DATA);
                    
                    TEMP = call Transport.read(fd);
                    mySocket->effectiveWindow = mySocket->effectiveWindow - myHeader->ack + TEMP;
                    // We don't want effectiveWindow == 0, or sender won't know when to send more data
                    // so, set effectiveWindow = 1 so that sender will keep trying and eventually recieve an ACK
                    if(mySocket->effectiveWindow == 0) mySocket->effectiveWindow += 1;
                } else {
                    dbg(TRANSPORT_CHANNEL, "Got %d, but still waiting on %d\n", myHeader->sequence, mySocket->nextExpected);    
                }
                makeTcpHeader(&sendTcpHeader, myHeader->destPort, myHeader->sourcePort, 0, mySocket->nextExpected, ACK, mySocket->effectiveWindow);
                makePack(&sendPackage, TOS_NODE_ID, package->src, 20, PROTOCOL_TCP, myHeader->sequence + 18, (uint8_t *) &sendTcpHeader, PACKET_MAX_PAYLOAD_SIZE);
                call Ip.ping(sendPackage);
            }
        }
        return FAIL;
    }

    command socket_t Transport.findSocket(uint8_t clientPort, uint16_t server, uint8_t serverPort) {
        uint32_t *keys = call sockets.getKeys();
        int i;
        for(i = call sockets.size() - 1; i >= 0; i--) {
            socket_store_t curr = call sockets.get(keys[i]);
            if(curr.src.port == clientPort && curr.dest.addr == server && curr.dest.port == serverPort) {
                return keys[i];
            }
        }
        return (uint8_t) 0;
    }

    command socket_t Transport.findUser(char *user) {
        uint32_t *keys = call sockets.getKeys();
        int i;
        for(i = call sockets.size() - 1; i >= 0; i--) {
            socket_store_t curr = call sockets.get(keys[i]);
            if(strcmp(curr.username, user) == 0) {
                return keys[i];
            }
        }
        return (uint8_t) 0;
    }

    command uint16_t Transport.read(socket_t fd) {
        socket_store_t *mySocket = call sockets.getPointer(fd);
        uint8_t *endIndex = strstr((const char*) &(mySocket->rcvdBuff[mySocket->lastReadIndex]), "\r\n");
        //uint8_t *cmd, *cmdMessage; 
        uint8_t netBytes = endIndex - &(mySocket->rcvdBuff[mySocket->lastReadIndex]);
        uint8_t bytesRead = netBytes + strlen("\r\n");

        if(endIndex == NULL) return 0;

        strncpy(cmdMessage, (const char*) &(mySocket->rcvdBuff[mySocket->lastReadIndex]), netBytes);
        cmdMessage[netBytes] = '\0';
    
        call Application.read(mySocket, cmdMessage);

        mySocket->lastRead += (netBytes + 3);
        mySocket->lastReadIndex += (netBytes + 3);
        return bytesRead;
    }


    command error_t Transport.connect(socket_t fd, socket_addr_t * address) {
        socket_store_t *currSocket = call sockets.getPointer(fd);
        currSocket->dest = *address;
        currSocket->lastSent = call Random.rand16() % 500;
        currSocket->lastAckIndex = 0;
        makeTcpHeader(&sendTcpHeader, currSocket->src.port, address->port, currSocket->lastSent, 0, SYN, 0);

        makePack(&sendPackage, TOS_NODE_ID, (uint16_t) address->addr, currSocket->lastSent, PROTOCOL_TCP, sendTcpHeader.sequence, (uint8_t *) &sendTcpHeader, PACKET_MAX_PAYLOAD_SIZE);
        call Ip.ping(sendPackage);

        //dbg(TRANSPORT_CHANNEL, "SYN packet sent to Node %d, port %d\n", address->addr, address->port);
        currSocket->state = SYN_SENT;
        call synTimer.startOneShot(5000);
        return SUCCESS;
    }

    event void synTimer.fired() {
        uint32_t *keys = call sockets.getKeys();
        int i;
        for(i = call sockets.size() - 1; i >= 0; i--) {
            socket_store_t *mySocket = call sockets.getPointer(keys[i]);
            // Start send from whatever was last ACKed
            if(mySocket->state == SYN_SENT) {
                // If it's still SYN_SENT, then send try connecting again.
                dbg(TRANSPORT_CHANNEL, "Attempting to connect from %d:%d to %d:%d again\n", TOS_NODE_ID, mySocket->src.port, mySocket->dest.addr, mySocket->dest.port);
                call Transport.connect(keys[i], &(mySocket->dest));
            }
        }
    }

    event void synackTimer.fired() {
        // Challenge: how do I tell which socket is the one that I need to re-send the SYNACK for?
        // Because, I don't know when accept() finishes.
        uint32_t *keys = call sockets.getKeys();
        int i, j;
        for(i = call sockets.size() - 1; i >= 0; i--) {
            socket_store_t *mySocket = call sockets.getPointer(keys[i]);
            if(mySocket->state != SYN_RCVD) continue;
        
            dbg(TRANSPORT_CHANNEL, "Send SYNACK again %d:%d to %d:%d again\n", TOS_NODE_ID, mySocket->src.port, mySocket->dest.addr, mySocket->dest.port);
            for(j = call attemptedConnections.size(); j > 0; j--) {            
                connection curr = call attemptedConnections.popfront();
                // Likely the matching connection
                if(curr.serverPort == mySocket->src.port) {
                    makeTcpHeader(
                        &sendTcpHeader, curr.serverPort, curr.clientPort, call Random.rand16() % 500, 
                        curr.seqNum + 1, SYNACK, TCP_MAX_DATA * 3
                    );
                    makePack(&sendPackage, TOS_NODE_ID, curr.clientNode, 20, PROTOCOL_TCP, sendTcpHeader.sequence, (uint8_t *) &sendTcpHeader, PACKET_MAX_PAYLOAD_SIZE);
                    call Ip.ping(sendPackage);
                }
                call attemptedConnections.pushback(curr);
            }
        }
    }

    command error_t Transport.close(socket_t fd) {
        socket_store_t *mySocket = call sockets.getPointer(fd);
        if(fd == 0 || mySocket->state != ESTABLISHED) {
            dbg(TRANSPORT_CHANNEL, "Socket is not Established\n");
            return FAIL;
        }
        mySocket->state = CLOSED;

        makeTcpHeader(&sendTcpHeader, mySocket->src.port, mySocket->dest.port, mySocket->lastSent + 1, 0, FIN, 0);
        makePack(&sendPackage, TOS_NODE_ID, mySocket->dest.addr, 20, PROTOCOL_TCP, mySocket->lastSent + 18, (uint8_t *) &sendTcpHeader, PACKET_MAX_PAYLOAD_SIZE);
        call Ip.ping(sendPackage);
        
        return SUCCESS;
    }

    command error_t Transport.release(socket_t fd) {
        return FAIL;
    }

    command error_t Transport.listen(socket_t fd) {
        socket_store_t *mySocket = call sockets.getPointer((uint32_t) fd);
        mySocket->state = LISTEN;
        return SUCCESS;
    }

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
		Package->src = src;
		Package->dest = dest;
		Package->TTL = TTL;
		Package->seq = seq;
		Package->protocol = protocol;
		memcpy(Package->payload, payload, length);
	}
    void makeTcpHeader(tcpHeader *myTcpHeader, uint8_t sourcePort, uint8_t destPort, uint16_t sequence, uint16_t ack, enum flags flag, uint16_t advertisedWindow){
		myTcpHeader->sourcePort = sourcePort;
        myTcpHeader->destPort = destPort;
        myTcpHeader->sequence = sequence;
        myTcpHeader->ack = ack;
        myTcpHeader->flag = flag;
        myTcpHeader->advertisedWindow = advertisedWindow;
		//memcpy(myTcpHeader->payload, data, PACKET_MAX_PAYLOAD_SIZE);
	}
}
