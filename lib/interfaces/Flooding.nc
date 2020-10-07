interface Flooding{
	command bool checkCache(int src, int seqNum);
	command void floodSend(pack x, uint16_t from, uint16_t destination, uint8_t* payload); 
}