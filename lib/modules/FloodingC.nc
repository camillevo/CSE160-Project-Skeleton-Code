configuration FloodingC {
	provides interface Flooding;
	
}

implementation {

	components FloodingP;
	Flooding = FloodingP.Flooding;

	components new SimpleSendC(AM_PACK);
    FloodingP.SimpleSend -> SimpleSendC;

}