#ifndef MESSAGE_H
#define MESSAGE_H

typedef nx_struct ConnectMessage {

	nx_uint8_t ID;
	nx_uint8_t clientID;

} ConnectMessage;

typedef nx_struct AckMessage {

	nx_uint8_t ID;
	nx_uint8_t clientID;
	nx_uint8_t code;
	
} AckMessage;

typedef nx_struct SubscribeMessage {

	nx_uint8_t ID;	
	nx_uint8_t clientID;	
	nx_uint8_t topic1;
	nx_uint8_t topic2;
	nx_uint8_t topic3;
	nx_uint8_t qos;

} SubscribeMessage;

typedef nx_struct PublishMessage {

	nx_uint8_t ID;
	nx_uint8_t clientID;	
	nx_uint8_t topicID;// 0: TEMP, 1:HUM, 2: LUM
	nx_uint8_t qos;
	nx_uint8_t payload;

} PublishMessage;

enum{

	AM_MY_MSG = 6,

};

#endif
