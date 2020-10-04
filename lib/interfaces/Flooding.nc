interface Flooding{
	command bool checkCache(int src, int seqNum);
	command void floodSend(pack x, int* neighborArr); 
}