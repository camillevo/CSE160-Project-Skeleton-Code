#include "../../includes/packet.h"
#include "../../includes/socket.h"

module ApplicationP{
    provides interface Application;

    uses interface Transport;
}

implementation{
    char final[20];
    char* msg, *cmd;

    int findCommand(uint8_t *cmdString);
    uint8_t readClient(socket_store_t *mySocket, char *message);
    char* concatString(char* dest, char* first, char* second);

    command uint8_t Application.read(socket_store_t *mySocket, char *message) {
        int temp;

        if(TOS_NODE_ID != 1) {
            return readClient(mySocket, message);
        }

        dbg(TRANSPORT_CHANNEL, "Got command \"%s\"\n", message);

        cmd = strtok(message, " ");
        switch(findCommand(cmd)) {
            case 0: 
                msg = strtok(NULL, " ");
                strncpy(mySocket->username, msg, strlen(msg) + 1);
                break;
            case 1: 
                msg = strtok(NULL, "");
                concatString(final, mySocket->username, msg);
                call Transport.writeAll(final);
                break;
            default:
                dbg(TRANSPORT_CHANNEL, "Not a known command\n");
                break;
        }

        return 1;

    }

    uint8_t readClient(socket_store_t *mySocket, char *message) {
        char * user = strtok(message, " ");
        //char * myMsg = strtok(NULL, "");

        dbg(TRANSPORT_CHANNEL, "%s says: %s\n", user, strtok(NULL, ""));
        
        mySocket->lastRead += (strlen(message) + 3);
        mySocket->lastReadIndex += (strlen(message) + 3);
        return strlen(message);
    }

    int findCommand(uint8_t *cmdString) {
        //cmd = strtok((char*)cmdString, " ");
        if(strcmp(cmdString, "hello") == 0) {
            return 0;
        } else if(strcmp(cmdString, "msg") == 0) {
            return 1;
        } else {
            return 5;
        }
    }

    char* concatString(char* dest, char* first, char* second) {
        char * string = malloc(strlen(first) + strlen(second) + 5);
        strncpy(string, first, strlen(first));
        string[strlen(first)] = ' ';
        strncpy(&(string[strlen(first) + 1]), second, strlen(second) + 1);
        strncpy(&(string[strlen(string)]), "\r\n\0", 5);
        strcpy(dest, string);
        return string;
    }
}