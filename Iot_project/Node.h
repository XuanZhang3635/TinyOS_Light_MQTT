#ifndef NODE_H
#define NODE_H

#define N_NODES 8 // 8 nodes with id : 2,3,4,5,6,7,8,9
#define N_TOPICS 3 // 3 topics: TEMPERATURE, HUMIDITY, LUMINOSITY

#define BROKER_ID 1
#define CAPACITY 150 // the size of PANC buffer

/** Node state === 
*** NODE_BOOTED: node boots successfully
*** NODE_CONNECTED: node connect to the broker successfully
*** NODE_ACTIVE: the PANC boots successfully
**/
#define NODE_BOOTED 0
#define NODE_CONNECTED 1
#define NODE_ACTIVE 2

// Assume QOS = 0 both sub and pub
#define PUBQOS 0
#define SUBQOS 0
#define CONNACK 2
#define SUBACK 4

#define TIME_PERIOD_TEMP 6000
#define TIME_PERIOD_HUM 14000
#define TIME_PERIOD_LUM 8000

#define TEMP_RANGE 60
#define HUM_RANGE 100
#define LUM_RANGE 100

// 0:TEMP,1:HUM,2:LUM
uint8_t PUBLICATION_TOPIC[N_NODES] = {
	0,1,2,0,1,0,2,0
};


// 0: Not subscribed, 1: Subscribed
// requirement: at least 3 nodes subscribing to more than 1 topic
uint8_t SUBSCRIPTIONS_TOPIC[N_TOPICS][N_NODES] = {

	{1,0,0,0,0,1,1,1},//TEMP
	{1,1,1,1,0,0,1,1},//HUM
	{0,1,1,0,1,0,1,1} //LUM

};

#endif

