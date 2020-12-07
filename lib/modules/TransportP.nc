#include "../../includes/packet.h"
#include "../../includes/socket.h"

module TransportP{
  provides interface Transport;

  uses interface Hashmap<socket_store_t> as sockets;
  uses interface List<connection> as attemptedConnections;
  uses interface Timer<TMilli> as resendTimer;
  uses interface Timer<TMilli> as synTimer;
  uses interface Timer<TMilli> as synackTimer;
  uses interface Random;
  uses interface Ip;
}

implementation{
    pack sendPackage;
    tcpHeader sendTcpHeader;
    
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
    void makeTcpHeader(tcpHeader *myHeader, uint8_t sourcePort, uint8_t destPort, uint16_t sequence, uint16_t ack, enum flags flag, uint16_t advertisedWindow);
    //socket_t findSocket(uint16_t server, uint8_t serverPort, uint8_t clientPort) {


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
        newSocket.lastWritten = 0; // Server isn't writing anything
        newSocket.lastSent = 0;
        newSocket.lastRead = curr.seqNum;
        newSocket.lastRcvd = curr.seqNum;
        newSocket.lastReadIndex = 0;
        newSocket.nextExpected = curr.seqNum + 1;
        newSocket.effectiveWindow = TCP_MAX_DATA * 2;

        call sockets.insert(newFD, newSocket);

        dbg(TRANSPORT_CHANNEL, "Accepted connection on port %d from Node %d, port %d\n", 
            newSocket.src.port, newSocket.dest.addr, newSocket.dest.port);
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

        dbg(TRANSPORT_CHANNEL, "Wrote %d bytes at buff[%d]\n", min, currIndex);
                       
        memcpy(&(mySocket->sendBuff[currIndex]), buff, SOCKET_BUFFER_SIZE - currIndex);
        mySocket->lastWritten = mySocket->lastWritten + min;

        call Transport.sendBuffer(mySocket);

        return min;
    }

    command void Transport.sendBuffer(socket_store_t *mySocket) {
        //printf("lastWritten: %d, lastSent: %d\n", mySocket->lastWritten, mySocket->lastSent);
        if(mySocket->state != ESTABLISHED) {
            dbg(TRANSPORT_CHANNEL, "Socket on port %d is not yet established.\n", mySocket->src.addr);
            return;
        }
        while(mySocket->effectiveWindow > 0) {
            int i;
            // Find min of effectiveWindow, lastWritten, and TCP_MAX_DATA
            uint8_t bytesToSend = (uint8_t)(mySocket->lastWritten - mySocket->lastSent - 1) > TCP_MAX_DATA ? TCP_MAX_DATA : (uint8_t)(mySocket->lastWritten - mySocket->lastSent - 1);
            if(mySocket->effectiveWindow < bytesToSend) bytesToSend = mySocket->effectiveWindow;
            //printf("sendBuffer() effectiveWindow = %d\n", mySocket->effectiveWindow);
            if(bytesToSend == 0) {
                dbg(TRANSPORT_CHANNEL, "Need more data on port %d!\n", mySocket->src.port);
                return;
            }
            // Setting effectiveWindow to 0 because Server doesn't need it
            // Repurposing ACK to store length of payload
            makeTcpHeader(
                &sendTcpHeader, mySocket->src.port, mySocket->dest.port, mySocket->lastSent + 1, 
                bytesToSend, NONE, 0
            );
            //(&sendTcpHeader)->length = bytesToSend;
            memcpy((&sendTcpHeader)->payload, &(mySocket->sendBuff[mySocket->lastSent + 1 - mySocket->lastAck + mySocket->lastAckIndex]), bytesToSend);

            makePack(&sendPackage, TOS_NODE_ID, mySocket->dest.addr, 20, PROTOCOL_TCP, 
                sendTcpHeader.sequence, (uint8_t *) &sendTcpHeader, TCP_HEADER_LENGTH + bytesToSend
            );
            //printf("sizeof tcp header = %d\n", sizeof(sendTcpHeader));
            //dbg(TRANSPORT_CHANNEL, "Sent bytes %d to %d on port %d\n", mySocket->lastSent + 1, mySocket->lastSent + bytesToSend, mySocket->src.port);
            call Ip.ping(sendPackage);
            mySocket->lastSent += bytesToSend;
            mySocket->effectiveWindow -= bytesToSend;
        }
        // If there's more to write, then call resend timer.
        // +-1 is wiggle room for my own potential errors in indexing
        if(mySocket->lastSent < mySocket->lastWritten - 1 || mySocket->lastSent > mySocket->lastWritten + 1) {
            call resendTimer.startOneShot(1500);
        } else {
            //dbg(TRANSPORT_CHANNEL, "lastWritten = %d, lastSent = %d\n", mySocket->lastWritten, mySocket->lastSent);
        }
    }

    event void resendTimer.fired() {
        // Iterate thru sockets
        uint32_t *keys = call sockets.getKeys();
        int i;
        //printf("Sanity check: there are %d sockets for Node %d\n", call sockets.size(), TOS_NODE_ID);
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
                call attemptedConnections.pushfront(myConnection);
                dbg(TRANSPORT_CHANNEL, "SYN received from Node %d, port %d\n", package->src, myHeader->sourcePort);

                mySocket->state = SYN_RCVD;

                makeTcpHeader(
                    &sendTcpHeader, myHeader->destPort, myConnection.clientPort, call Random.rand16() % 500, 
                    myConnection.seqNum + 1, SYNACK, TCP_MAX_DATA * 2
                );
                makePack(&sendPackage, TOS_NODE_ID, myConnection.clientNode, 20, PROTOCOL_TCP, sendTcpHeader.sequence, (uint8_t *) &sendTcpHeader, PACKET_MAX_PAYLOAD_SIZE);
                call Ip.ping(sendPackage);
                
                call synackTimer.startOneShot(1200);
                return SUCCESS;
            }
            break;
            case SYNACK: {
                dbg(TRANSPORT_CHANNEL, "SYNACK received from Node %d, port %d\n", package->src, myHeader->sourcePort);

                // check if ack is the same as the sequence I sent
                if(myHeader->ack != mySocket->lastSent + 1) {
                    return FAIL;
                }
                if(call synTimer.isRunning()) call synTimer.stop();

                mySocket->nextExpected = myHeader->sequence + 1;
                mySocket->lastAck = myHeader->ack;
                mySocket->lastWritten = mySocket->lastAck;
                mySocket->state = ESTABLISHED;
                mySocket->effectiveWindow = myHeader->advertisedWindow;
                dbg(TRANSPORT_CHANNEL, "Connection is established! Will start sending data with seq = %d\n", myHeader->ack);
                // Do ACKs have sequences? For now I am assuming they don't????
                makeTcpHeader(&sendTcpHeader, myHeader->destPort, myHeader->sourcePort, 3, myHeader->sequence + 1, ACK, 0);
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

                dbg(TRANSPORT_CHANNEL, "ACK: %d received from Node %d, port %d\n", myHeader->ack, package->src, myHeader->sourcePort);
            }
            break;
            default: {
                uint8_t TEMP;
                //printf("seq recieved %d, lastRead %d, lastReadIndex %d\n", myHeader->sequence, mySocket->lastRead, mySocket->lastReadIndex);
                if(myHeader->sequence <= mySocket->nextExpected || myHeader->sequence + myHeader->ack <= mySocket->nextExpected) {
                    // ack field is repurposed as size on client side
                    mySocket->nextExpected = myHeader->sequence + myHeader->ack;
                    mySocket->lastRcvd = myHeader->sequence + myHeader->ack - 1;
                    
                    memcpy(&(mySocket->rcvdBuff[(uint8_t)(myHeader->sequence - mySocket->lastRead - 1 + mySocket->lastReadIndex)]), myHeader->payload, TCP_MAX_DATA);
                    //dbg(TRANSPORT_CHANNEL, "Writing at rcvdBuffer[%d]\n", (uint8_t) (myHeader->sequence - mySocket->lastRead - 1 + mySocket->lastReadIndex));

                    TEMP = call Transport.read(fd);
                    mySocket->effectiveWindow = mySocket->effectiveWindow - myHeader->ack + TEMP;
                    //dbg(TRANSPORT_CHANNEL, "Advertising my window as %d\n", mySocket->effectiveWindow);
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

    command uint16_t Transport.read(socket_t fd) {
        // Proj 3: print all the bytes I can, return amount printed
        socket_store_t *mySocket = call sockets.getPointer(fd);
        int i;
        uint8_t endIndex;
        uint8_t netBytes = mySocket->lastRcvd - mySocket->lastRead;
        netBytes = netBytes - (netBytes % 2); // only read even number
        endIndex = netBytes + mySocket->lastReadIndex - 1;

        //dbg(TRANSPORT_CHANNEL, "Reading from [%d] to [%d]\n", mySocket->lastReadIndex, endIndex);
        dbg(TRANSPORT_CHANNEL, "Received data ");
        for(i = mySocket->lastReadIndex; i <= endIndex; i += 2) {
            printf("%d, ", (mySocket->rcvdBuff[i] << 8) + mySocket->rcvdBuff[i + 1]);
        }
        // for(i = mySocket->lastReadIndex; i <= endIndex; i++) {
        //     printf("%d, ", mySocket->rcvdBuff[i]);
        // }
        printf("from %d:%d\n", mySocket->dest.addr, mySocket->dest.port);

        mySocket->lastRead += netBytes;
        mySocket->lastReadIndex = endIndex + 1;

        if(endIndex > SOCKET_BUFFER_SIZE / 2) {
            memcpy(&(mySocket->rcvdBuff[0]), &(mySocket->rcvdBuff[mySocket->lastReadIndex + 1]), netBytes);
            mySocket->lastReadIndex = 0;
            //dbg(TRANSPORT_CHANNEL, "Removed %d bytes from rcvdBuff\n", netBytes);
        }

        return netBytes;
    }

    command error_t Transport.connect(socket_t fd, socket_addr_t * address) {
        socket_store_t *currSocket = call sockets.getPointer(fd);
        currSocket->dest = *address;
        currSocket->lastSent = call Random.rand16() % 500;
        currSocket->lastAckIndex = 0;
        makeTcpHeader(&sendTcpHeader, currSocket->src.port, address->port, currSocket->lastSent, 0, SYN, 0);

        makePack(&sendPackage, TOS_NODE_ID, (uint16_t) address->addr, 20, PROTOCOL_TCP, sendTcpHeader.sequence, (uint8_t *) &sendTcpHeader, PACKET_MAX_PAYLOAD_SIZE);
        call Ip.ping(sendPackage);

        dbg(TRANSPORT_CHANNEL, "SYN packet sent to Node %d, port %d\n", address->addr, address->port);
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
                        curr.seqNum + 1, SYNACK, TCP_MAX_DATA * 2
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
