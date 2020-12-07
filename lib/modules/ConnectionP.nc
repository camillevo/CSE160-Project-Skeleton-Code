#include "../../includes/packet.h"
#include "../../includes/socket.h"

module ConnectionP{
    provides interface Connection;

    uses interface Timer<TMilli> as connectTimer;
    uses interface Timer<TMilli> as acceptTimer;
    uses interface Transport;
}

implementation{
    // 0: file descriptor
    // 1: for server: listening or established
    //    for client: # of bytes already sent
    // 2: for client: total bytes

    int messageCache[5][3] = {{0}};
    uint8_t dataBuffers[5][128] = {{0}};

    command void Connection.testServer(int port) {
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

        call acceptTimer.startOneShot(13968);
    }


	command void Connection.testClient(int destination, int sourcePort, int destPort, int transfer){
        int i, j;
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
                messageCache[i][1] = 0;
                messageCache[i][2] = transfer;
                break;
            }
        }

        call Transport.connect(mySocketFD, &destAddress);
        // copy the transfer data to buffer
        // for(j = 0; j < transfer; j++) {
        //     dataBuffers[i][j] = j;
        // }

        call connectTimer.startOneShot(20968);
	}

    event void connectTimer.fired() {
        // loop through cache
        // challenge is writing # of transfer bytes to the buffer
        int i, j, currByte, oldByte;
        bool dataLeft = FALSE;

        for(i = 0; i < 5; i++) {
            if(messageCache[i][0] == 0) continue;
            if(messageCache[i][1] == messageCache[i][2]) {
                dbg(TRANSPORT_CHANNEL, "Wrote all my data!\n");
                dataLeft = dataLeft || FALSE;
                continue;
            }
            dataLeft = TRUE;
            currByte = messageCache[i][1];
            oldByte = messageCache[i][1];
            // Write remaining data to buffer
            for(j = 0; j < 128; j++) {
                if(currByte == messageCache[i][2]) break;
                dataBuffers[i][j] = currByte;
                currByte++;
            }
            messageCache[i][1] = messageCache[i][1] + call Transport.write(messageCache[i][0], &dataBuffers[i], currByte - oldByte);
            //dbg(TRANSPORT_CHANNEL, "XXXXXXX Wrote from byte %d to byte %d\n", oldByte, messageCache[i][1]);
        }
        if(dataLeft) {
            call connectTimer.startOneShot(9990);
        }
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
                            //printf("added newly made socket to my array\n");
                            break;
                        }
                    }
                    call acceptTimer.startOneShot(15968);
                }
            }

        }
        return;
    }

    command void Connection.clientClose(int dest, int srcPort, int destPort){
        //dbg(TRANSPORT_CHANNEL, "closing socket src: %d %d, dest: %d %d\n", TOS_NODE_ID, srcPort, dest, destPort);
        socket_t mySocket = call Transport.findSocket(srcPort, dest, destPort);
        if(call Transport.close(mySocket) == SUCCESS) {
            dbg(TRANSPORT_CHANNEL, "Connection from %d:%d to %d:%d successfully closed\n", TOS_NODE_ID, srcPort, dest, destPort);
        } else {
            dbg(TRANSPORT_CHANNEL, "ERROR - Connection could not be closed\n");
        }
    }

}
