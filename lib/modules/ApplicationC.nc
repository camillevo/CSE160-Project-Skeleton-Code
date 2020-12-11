#include <Timer.h>
#include "../../includes/packet.h"

configuration ApplicationC{
    provides interface Application;
}
implementation {
    components ApplicationP;
    Application = ApplicationP.Application;

    components TransportC;
    ApplicationP.Transport -> TransportC;
}