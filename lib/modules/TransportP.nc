#include "../../includes/packet.h"
#include "../../includes/socket.h"

module TransportP{
  provides interface Transport;

  uses interface Hashmap<socket_store_t> as sockets;
  uses interface List<connection> as attemptedConnections;
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
        for(i = call attemptedConnections.size() - 1; i >= -1; i--) {
            if(i == -1) return (uint8_t) 0;
            
            curr = call attemptedConnections.popfront();
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
        newSocket.lastRead = curr.seqNum;
        newSocket.lastRcvd = curr.seqNum;
        newSocket.nextExpected = curr.seqNum + 1;

        call sockets.insert(newFD, newSocket);

        dbg(TRANSPORT_CHANNEL, "Accepted connection on port %d from Node %d, port %d\n", 
            newSocket.src.port, newSocket.dest.addr, newSocket.dest.port);
        return newFD;
    }

    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen) {
        socket_store_t *mySocket = call sockets.getPointer(fd);
        // check space in buffer
        // if it has space, write the remaining amount to the buffer
        // check effective window size = advertised window - (lastSent - lastAck)
        // while effective window > 0, 
        //     make tcpHeader and pack and send 1 pack of data
        //          need to find a way to wait for ack
        //     seqNum is = lastAck
        //     increase lastSent
        //     decrease effectiveWindow
        // return the amount of data able to write

        return bufflen;
    }

    command error_t Transport.receive(pack* package) {
        tcpHeader *myHeader = package->payload;

        switch(myHeader->flag) {
            case SYN: {
                connection myConnection;
                myConnection.clientNode = package->src;
                myConnection.clientPort = myHeader->sourcePort;
                myConnection.seqNum = myHeader->sequence;
                myConnection.serverPort = myHeader->destPort;
                call attemptedConnections.pushfront(myConnection);
                dbg(TRANSPORT_CHANNEL, "SYN received from Node %d, port %d\n", package->src, myHeader->sourcePort);

                makeTcpHeader(
                    &sendTcpHeader, myHeader->destPort, myConnection.clientPort, call Random.rand16() % 500, 
                    myConnection.seqNum + 1, SYNACK, 1
                );
                makePack(&sendPackage, TOS_NODE_ID, myConnection.clientNode, 20, PROTOCOL_TCP, sendTcpHeader.sequence, (uint8_t *) &sendTcpHeader, PACKET_MAX_PAYLOAD_SIZE);
                call Ip.ping(sendPackage);
                return SUCCESS;
            }
            break;
            case SYNACK: {
                socket_t fd = call Transport.findSocket(myHeader->destPort, package->src, myHeader->sourcePort);
                socket_store_t *mySocket = call sockets.getPointer(fd);
                dbg(TRANSPORT_CHANNEL, "SYNACK received from Node %d, port %d\n", package->src, myHeader->sourcePort);

                // check if ack is the same as the sequence I sent
                if(myHeader->ack != mySocket->lastSent + 1) {
                    return FAIL;
                }
                mySocket->nextExpected = myHeader->sequence + 1;
                mySocket->lastAck = myHeader->ack;
                mySocket->state = ESTABLISHED;
                mySocket->effectiveWindow = myHeader->advertisedWindow;
                dbg(TRANSPORT_CHANNEL, "Connection is established! Can start sending data\n");

                // CAMILLE FIX SEQUENCE NUMBER LATER    
                makeTcpHeader(&sendTcpHeader, myHeader->destPort, myHeader->sourcePort, 3, myHeader->sequence + 1, ACK, 0);
                makePack(&sendPackage, TOS_NODE_ID, package->src, 20, PROTOCOL_TCP, sendTcpHeader.sequence, (uint8_t *) &sendTcpHeader, PACKET_MAX_PAYLOAD_SIZE);
                call Ip.ping(sendPackage);
                return SUCCESS;
            }
            break;
            case ACK: {
                // increase lastAck
                // see what the advertised window is and adjust effective window accordingly
                dbg(TRANSPORT_CHANNEL, "ACK received from Node %d, port %d\n", package->src, myHeader->sourcePort);
            }
            // default
            // copy data to socket buffer
            // increase last rcvd and nextExpected
            // make tcpHeader with advertised window
            // send ACK back
        }
        return FAIL;
    }

    command bool Transport.establishSocket(int fd, uint8_t clientPort, uint16_t server, uint8_t serverPort) {
        socket_store_t *curr = call sockets.getPointer(fd);
        if(curr->src.port == clientPort && curr->dest.addr == server && curr->dest.port == serverPort) {
            curr->state = ESTABLISHED;
            return TRUE;
        }
        return FALSE;
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
        dbg(TRANSPORT_CHANNEL, "didn't find socket :/\n");
        return (uint8_t) 0;
    }

    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen) {
        // Called from acceptTimer() for sockets marked as established
        // copy length of what's in socket buffer to *buff
        // increase lastRead
        // return length of what was in buffer
        return bufflen;
    }

    command error_t Transport.connect(socket_t fd, socket_addr_t * address) {
        socket_store_t *currSocket = call sockets.getPointer(fd);
        currSocket->dest = *address;
        currSocket->lastWritten = call Random.rand16() % 500;
        currSocket->lastSent = currSocket->lastWritten;
        currSocket->lastAck = currSocket->lastWritten;
        makeTcpHeader(&sendTcpHeader, currSocket->src.port, address->port, currSocket->lastSent, 0, SYN, 0);

        makePack(&sendPackage, TOS_NODE_ID, (uint16_t) address->addr, 20, PROTOCOL_TCP, sendTcpHeader.sequence, (uint8_t *) &sendTcpHeader, PACKET_MAX_PAYLOAD_SIZE);
        call Ip.ping(sendPackage);

        dbg(TRANSPORT_CHANNEL, "SYN packet sent to Node %d, port %d\n", address->addr, address->port);
        currSocket->state = SYN_SENT;
        return SUCCESS;
    }

    command error_t Transport.close(socket_t fd) {
        return FAIL;
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
