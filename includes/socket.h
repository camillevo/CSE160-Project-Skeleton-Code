#ifndef __SOCKET_H__
#define __SOCKET_H__

# include "packet.h"

enum{
    MAX_NUM_OF_SOCKETS = 10,
    ROOT_SOCKET_ADDR = 255,
    ROOT_SOCKET_PORT = 255,
    SOCKET_BUFFER_SIZE = 128,
    TCP_HEADER_LENGTH = 9,
    TCP_MAX_DATA = PACKET_MAX_PAYLOAD_SIZE - TCP_HEADER_LENGTH
};

enum socket_state{
    CLOSED,
    LISTEN,
    ESTABLISHED,
    SYN_SENT,
    SYN_RCVD,
};

enum flags{
    ACK,
    SYNACK,
    SYN,
    FIN,
    NONE
};


typedef nx_uint8_t nx_socket_port_t;
typedef uint8_t socket_port_t;

// socket_addr_t is a simplified version of an IP connection.
typedef nx_struct socket_addr_t{
    nx_socket_port_t port;
    nx_uint16_t addr;
}socket_addr_t;


// File descripter id. Each id is associated with a socket_store_t
typedef uint8_t socket_t;

// State of a socket. 
typedef struct socket_store_t{
    uint8_t flag;
    enum socket_state state;
    socket_addr_t src;
    socket_addr_t dest;

    // This is the sender portion.
    uint8_t sendBuff[SOCKET_BUFFER_SIZE];
    uint8_t lastWritten;
    uint8_t lastAck;
    uint8_t lastSent;
    uint8_t lastAckIndex;

    // This is the receiver portion
    uint8_t rcvdBuff[SOCKET_BUFFER_SIZE];
    uint8_t lastRead;
    uint8_t lastRcvd;
    uint8_t nextExpected;
    uint8_t lastReadIndex;

    uint16_t RTT;
    uint8_t effectiveWindow;
}socket_store_t;


typedef struct tcpHeader{
    nx_socket_port_t sourcePort;
    nx_socket_port_t destPort;
    uint8_t sequence;
    uint8_t ack;
    //uint8_t length;
    enum flags flag;
    uint8_t advertisedWindow;
    uint8_t payload[TCP_MAX_DATA];
}tcpHeader;

typedef struct connection{
    uint16_t clientNode;
    nx_socket_port_t clientPort;
    nx_socket_port_t serverPort;
    int seqNum;
}connection;

#endif
