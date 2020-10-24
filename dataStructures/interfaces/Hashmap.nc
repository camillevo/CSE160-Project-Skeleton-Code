/**
 * ANDES Lab - University of California, Merced
 * This is an interface for Hashmaps.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 * 
 */

interface Hashmap<t>{
   command void insert(uint32_t key, t input);
   command void remove(uint32_t key);
   command t get(uint32_t key);
   command t* getPointer(uint32_t k);
   command bool contains(uint32_t key);
   command bool isEmpty();
   command void clear();
   command uint16_t size();
   command uint32_t * getKeys();
}
