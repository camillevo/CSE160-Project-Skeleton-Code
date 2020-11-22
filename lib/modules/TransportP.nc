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
    // CAMILLE COME BACK TO THIS
    command socket_t Transport.accept(socket_t fd){
        socket_store_t *currSocket = call sockets.getPointer(fd);
        if(currSocket->state == SYN_RCVD) {
            // Put currSocket in with a new fd, and put a clear socket in at the old fd
            socket_t newFD = call Transport.socket();
            call sockets.remove(fd);
            currSocket->state = ESTABLISHED;
            call sockets.insert((uint32_t) newFD, *currSocket);
            //socket_store_t tester = call sockets.get(newFD);
            if((call sockets.get(newFD)).state == ESTABLISHED) {
                dbg(TRANSPORT_CHANNEL, "it is established\n");
            }

            //socket_store_t newSocket;
            //memcpy(&newSocket, currSocket)
            //call Transport.socket();
        }


        return fd;
    }

    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen) {
        return bufflen;
    }

    command error_t Transport.receive(pack* package) {
        tcpHeader *myHeader = package->payload;

        switch(myHeader->flag) {
            case SYN: {
                connection myConnection;
                myConnection.node = package->src;
                myConnection.port = myHeader->sourcePort;
                myConnection.seqNum = myHeader->sequence;
                dbg(TRANSPORT_CHANNEL, "SYN received from Node %d, port %d\n", package->src, myHeader->sourcePort);

                myHeader->sourcePort = myHeader->destPort;
                myHeader->destPort = myConnection.port;
                myHeader->sequence = call Random.rand16() % 500;
                myHeader->flag = SYN;

            }
            break;

        }
        return FAIL;
    }

    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen) {
        return bufflen;
    }

    command error_t Transport.connect(socket_t fd, socket_addr_t * address) {
        socket_store_t *currSocket = call sockets.getPointer(fd);
        makeTcpHeader(&sendTcpHeader, currSocket->src.port, address->port, call Random.rand16() % 500, 0, SYN, 0);

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
