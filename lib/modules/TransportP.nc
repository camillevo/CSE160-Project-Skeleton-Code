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
    
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

    command socket_t Transport.socket() {
        if(call sockets.size() < 10) {
            return( (socket_t) call Random.rand16() % 255);
        };
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
        return fd;
    }

    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen) {
        return bufflen;
    }

    // Store attempted connection in a buffer somewhere
    /* 
typedef struct tcpHeader{
    nx_socket_port_t sourcePort;
    nx_socket_port_t destPort;
    uint16_t sequence;
    uint16_t ack;
    enum flags flag;
    uint16_t advertisedWindow;
    pack data;
}tcpHeader;
*/
    command error_t Transport.receive(pack* package) {
        tcpHeader *myHeader = package->payload;

        switch(myHeader->flag) {
            case SYN: {
                connection myConnection;
                myConnection.node = package->src;
                myConnection.port = myHeader->sourcePort;
                myConnection.seqNum = myHeader->sequence;
                dbg(TRANSPORT_CHANNEL, "SYN received from Node %d, port %d\n", package->src, myHeader->sourcePort);

                myHeader->sourcePort = currSocket->src.port;
                myHeader->destPort = address->port;
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
        tcpHeader myTcpHeader;
        socket_store_t *currSocket = call sockets.getPointer(fd);
        myTcpHeader.sourcePort = currSocket->src.port;
        myTcpHeader.destPort = address->port;
        myTcpHeader.sequence = call Random.rand16() % 500;
        myTcpHeader.flag = SYN;

        makePack(&sendPackage, TOS_NODE_ID, (uint16_t) address->addr, 20, PROTOCOL_TCP, myTcpHeader.sequence, (uint8_t *) &myTcpHeader, PACKET_MAX_PAYLOAD_SIZE);
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
}
