#include "Node.h"
#include "Message.h"
#include "printf.h"

module NodeC {

	uses {

		interface Boot;
		
		interface AMPacket;
		interface Packet as RadioPacket;
		interface AMSend; 
		interface Receive;
		interface SplitControl as AMControl;
		interface PacketAcknowledgements;
		
		/**
		*** Timer
		**/
		interface Timer<TMilli> as SendTimer; //millisecond
		interface Timer<TMilli> as ConnectTimeoutTimer;
		interface Timer<TMilli> as SubscribeTimeoutTimer;
		// providing temperature, humidity, and luminosity data to be published
		interface Timer<TMilli> as TimerTemp;
		interface Timer<TMilli> as TimerHum;
		interface Timer<TMilli> as TimerLum;
		interface Random;
	
	}

} implementation {

	// NODE state
	uint8_t state = 0;

	// MESSAGE PAYLOAD 
	void* conPayload;	
	void* pubPayload;
	void* subPayload;
	void* connackPayload;
	void* subackPayload;
  
    
	//BROKER VARIABLES
	bool connected_nodes[N_NODES]; // 1:Connect, 0:Disconnect
	bool topic_subs[N_TOPICS][N_NODES];
	uint8_t idProcessed[N_NODES]; // 1:Processed, 0:Unprocessed


	//NODE VARIABLES
	uint8_t pubTopic;
	uint8_t subscriptions[4];
	
	// Manage messages as a FIFO queue;
	message_t buffer[CAPACITY]; // messages in  the queue
	am_addr_t dest_addr[CAPACITY]; // the destination of messages
	uint8_t length[CAPACITY]; // the length of messages
	uint8_t head; // head of the queue
	uint8_t tail; // tail of the queue	
	uint8_t msgId;	// Message ID in the queue
	bool lock; // if the message is sent successfull, then release the lock
	bool full; 

	//======================= FUNCTIONS ===================//
	
	//Add to the queue a new ConnectMessage and starts SendTimer if needed
	error_t addConnect(){

		dbg("debug","[NODE %u] ADD CONNECT. head: %u, tail:%u\n",TOS_NODE_ID,head,tail);

		if(!full){
			ConnectMessage* conMsg;
			conMsg = (ConnectMessage*)(call AMSend.getPayload(&buffer[tail],sizeof(ConnectMessage)));

			conMsg->clientID = TOS_NODE_ID;
			conMsg->ID = msgId;

			msgId+=1;

			dbg("debug", "CONTENT IN node CONNECT: %u %u\n",conMsg->ID,conMsg->clientID);
			dest_addr[tail] = BROKER_ID;
			length[tail] = sizeof(ConnectMessage);
			tail = (tail+1)%CAPACITY;
		
			if(tail == head) {
				full = TRUE;
			}
		
			if(!(call SendTimer.isRunning())){
				call SendTimer.startOneShot(1000);
			}

			return SUCCESS;
		}else{
			dbg("error", "[ERROR] QUEUE IS FULL: could not put message on queue\n");
		}
		
		return FAIL;
	}
	//Add to the queue a new ConnackMessage and starts SendTimer if needed
	error_t addConnack(uint8_t dest){

		dbg("debug","[NODE %u] ADD CONNACK. head: %u, tail:%u\n",TOS_NODE_ID,head,tail);

		if(!full){
			AckMessage* ackMsg;
			ackMsg = (AckMessage*)(call AMSend.getPayload(&buffer[tail],sizeof(AckMessage)));

			ackMsg->clientID = TOS_NODE_ID;
			ackMsg->ID = msgId;
			ackMsg->code = CONNACK;
		
			msgId+=1;

			dbg("debug", "CONTENT IN CONNACK: %u %u %u\n",ackMsg->ID,ackMsg->clientID,ackMsg->code);
			dbg("debug", "DEST of CONNACK is: %d\n",dest);
			dest_addr[tail] = dest;
			length[tail] = sizeof(AckMessage);
			tail = (tail+1)%CAPACITY;
		
			if(tail == head) {
				full = TRUE;
			}
		
			if(!(call SendTimer.isRunning())){
				dbg("debug","start CONNACK Timer...\n");
				call SendTimer.startOneShot(1000);
			}

			return SUCCESS;
		}else{
			dbg("error", "[ERROR] QUEUE IS FULL: could not put message on queue\n");
		}
		return FAIL;
	}

	//Add to the queue a new SubscribeMessage and starts SendTimer if needed
	error_t addSubscribe(uint8_t* args){

		dbg("debug","[NODE %u] ADD SUBSCRIBE. head: %u, tail:%u\n",TOS_NODE_ID,head,tail);

		if(!full){
			SubscribeMessage* subMsg;
			subMsg = (SubscribeMessage*)(call AMSend.getPayload(&buffer[tail],sizeof(SubscribeMessage)));
			
			subMsg->ID = msgId;
			subMsg->clientID = TOS_NODE_ID;
			subMsg->topic1 = args[0];
			subMsg->topic2 = args[1];
			subMsg->topic3 = args[2];
			subMsg->qos = args[3];
			
			msgId+=1;

			dbg("debug", "CONTENT IN SUBSCRIBE: %u %u %u\n",subMsg->ID,subMsg->clientID);
			dest_addr[tail] = BROKER_ID;
			length[tail] = sizeof(SubscribeMessage);
			tail = (tail+1)%CAPACITY;
		
			if(tail == head) {
				full = TRUE;
			}
		
			if(!(call SendTimer.isRunning())){
				call SendTimer.startOneShot(1000);
			}

			return SUCCESS;
		}else{
			dbg("error", "[ERROR] QUEUE IS FULL: could not put message on queue\n");
		}
		return FAIL;
	}

	//Add to the queue a new SubackMessage and starts SendTimer if needed
	error_t addSuback(uint8_t dest){

		dbg("debug","[NODE %u] ADD SUBACK. head: %u, tail:%u\n",TOS_NODE_ID,head,tail);

		if(!full){
			AckMessage* ackMsg;
			ackMsg = (AckMessage*)(call AMSend.getPayload(&buffer[tail],sizeof(AckMessage)));

			ackMsg->clientID = TOS_NODE_ID;
			ackMsg->ID = msgId;
			ackMsg->code = SUBACK;
		
			msgId+=1;

			dbg("debug", "CONTENT IN SUBACK: %u %u %u\n",ackMsg->ID,ackMsg->clientID,ackMsg->code);
			dbg("node", "DEST of SUBACK is %d\n", dest );
			dest_addr[tail] = dest;
			length[tail] = sizeof(AckMessage);
			tail = (tail+1)%CAPACITY;
		
			if(tail == head) {
				full = TRUE;
			}
		
			if(!(call SendTimer.isRunning())){
				call SendTimer.startOneShot(1000);
			}

			return SUCCESS;
		}else{
			dbg("error", "[ERROR] QUEUE IS FULL: could not put message on queue\n");
		}
		return FAIL;
	}

	//Add to the queue a new PublishMessage and starts SendTimer if needed
	error_t addPublish(uint8_t* args){

		dbg("debug","[NODE %u] ADD PUBLISH. head: %u, tail:%u\n",TOS_NODE_ID,head,tail);

		if(!full){
			PublishMessage* pubMsg;
			pubMsg = (PublishMessage*)(call AMSend.getPayload(&buffer[tail],sizeof(PublishMessage)));
			
			pubMsg->ID = msgId;
			pubMsg->clientID = TOS_NODE_ID;
			pubMsg->topicID = args[0];
			pubMsg->payload = args[1];
			pubMsg->qos = args[2];
			
			msgId+=1;

			dbg("debug", "CONTENT IN PUBLISH: %u %u %u\n",pubMsg->ID,pubMsg->clientID); 
			
			dest_addr[tail] = args[3];
			length[tail] = sizeof(PublishMessage);
			tail = (tail+1)%CAPACITY;
		
			if(tail == head) {
				full = TRUE;
			}
		
			if(!(call SendTimer.isRunning())){
				call SendTimer.startOneShot(1000);
			}

			return SUCCESS;
		}else{
			dbg("error", "[ERROR] QUEUE IS FULL: could not put message on queue\n");
		}
		return FAIL;
	}
	
	void connect(){

		if(addConnect() == SUCCESS){

			dbg("node", "[NODE %u] sends CONNECT request to the BROKER \n",TOS_NODE_ID);

		} else {

			dbg("error", "[ERROR] sends CONNECT request failed!\n");

		}
		
		call ConnectTimeoutTimer.startOneShot(20000);

	}

	void subscribe(){	

		if(addSubscribe(subscriptions) == SUCCESS){

			dbg("node", "[NODE %u] SUBSCRIBE requested to the BROKER\n",TOS_NODE_ID);

		} else {
		
			dbg("error", "[ERROR] SUBSCRIBE request failed!\n");
			
		}

		call SubscribeTimeoutTimer.startOneShot(20000);

	}


	void publish(uint16_t value){

		uint8_t args[4] = {pubTopic,value,PUBQOS,BROKER_ID};

		if(addPublish(args) == SUCCESS){

			dbg("node", "[NODE %u] Enqueuing PUBLISH [Topic: %s | Payload: %u]\n",TOS_NODE_ID, \
				((args[0] == 0) ? "TEMP" : (args[0] == 1) ? "HUM" : "LUM"), args[1]);

		} 

	}

	//================== TASKS =====================//

	//Task used to send the head message in the queue. Radio resource is locked and will be released only
	//once the send has been done by the AMSend interface.
	task void sendTask(){

		message_t* p = &buffer[head];
			
		if(!lock && !full){
			lock = TRUE;

			// CONNECT and SUBSCRIBE needed to be acked
			if(length[head] == sizeof(ConnectMessage) || length[head] == sizeof(SubscribeMessage)){
				// dbg("debug", "the CONNECT and SUBSCIRBE msgs needs to be acked...\n");
				call PacketAcknowledgements.requestAck(p);					
			}

			if(call AMSend.send(dest_addr[head],p,length[head]) == SUCCESS){	
				full = FALSE;
				dbg("debug","[NODE %u]   SENDING message to %d from queue position %d SUCCESS\n", TOS_NODE_ID, dest_addr[head], head);
			}else{
				dbg("debug","[NODE %u]   SENDING message to %d from queue position %d FAILED\n", TOS_NODE_ID, dest_addr[head], head);
			} 					
					
		}

		//If there are messages and a timer is not running, starts the timer
		if(head!=tail && !(call SendTimer.isRunning())){
			call SendTimer.startOneShot(1000);
		}

	}

	/**
	*** for the broker, it needs to handle the connect, sub and pub requests
	*** connectionHandler()
	*** subscriptionHandler()
	*** publishHandler()
	**/
	task void connectionHandler(){	// handle connection
		
		ConnectMessage *conMsg;
		uint8_t i; // Only for debug
		conMsg=(ConnectMessage*) conPayload;
		dbg("node", "[BROKER] Received CONNECT [Src: %u]\n",conMsg->clientID);

		if(addConnack(conMsg->clientID) == SUCCESS){
			dbg("node", "[BROKER] Enqueuing CONNACK to %u\n",conMsg->clientID);
		} 
		
		connected_nodes[conMsg->clientID-2] = 1;

		for(i = 0; i < N_NODES; i++){
			dbg("debug","[BROKER] Node %d connecting state: %d\n",i+2,connected_nodes[i]);
		}

	}

	task void subscriptionHandler(){	// handle subscription
		
		SubscribeMessage *subMsg;		
		uint8_t i;
		subMsg=(SubscribeMessage*)subPayload;
		dbg("node", "[BROKER] Received SUBSCRIBE [Src: %u]\n", subMsg->clientID);
			
		if(subMsg->topic1){ // topic: TEMPERATURE

			dbg("node", "[BROKER] Subscribing node %d to topic \"TEMPERATURE\"\n", subMsg->clientID);
			topic_subs[0][subMsg->clientID-2] = 1;

		}else if(subMsg->topic2){ // topic: HUMIDITY

			dbg("node", "[BROKER] Subscribing node %d to topic \"HUMIDITY\"\n", subMsg->clientID);
			topic_subs[1][subMsg->clientID-2] = 1;

		}else if(subMsg->topic3){ // topic: LUMINOSITY

			dbg("node", "[BROKER] Subscribing node %d to topic \"LUMINOSITY\"\n", subMsg->clientID);
			topic_subs[2][subMsg->clientID-2] = 1;

		}

		if(addSuback(subMsg->clientID) == SUCCESS){
			dbg("node", "[BROKER] Enqueuing SUBACK to %u\n",subMsg->clientID);
		} 
		
	}

	task void publishHandler(){

		if(TOS_NODE_ID == 1){	//BROKER

			PublishMessage *pubMsg;
			uint8_t client;
			uint8_t n;
			uint8_t args[4]; // pubTopic,payload,pubQos,the destination of messages
					
			pubMsg=(PublishMessage*)pubPayload; 

			if(pubMsg->ID != idProcessed[(pubMsg->clientID)-2]){

				idProcessed[(pubMsg->clientID)-2] = pubMsg->ID;

				client = pubMsg->clientID;
				args[0] = pubMsg->topicID;
				args[1] = pubMsg->payload;

				dbg("node", "[BROKER] Received PUBLISH [Src: %u | Topic: %s | QoS: %u | Payload: %d]\n", client, \
					(args[0] == 0) ? "TEMP" : (args[0] == 1 ? "HUM" : "LUM"), pubMsg->qos, args[1]);
					
				//printf("%s,%d\n", (args[0] == 0) ? "TEMP" : (args[0] == 1 ? "HUM" : "LUM"), args[1]);
				//printfflush();

				for(n = 0; n < N_NODES; n++){

					// the publish msg will be forwarded by the PAN to all nodes that have subscribed to a particular topic
					if((n+2)!= client && connected_nodes[n] && topic_subs[args[0]][n]){

						args[2] = PUBQOS;
						args[3] = n + 2;
				
						if(addPublish(args) == SUCCESS){
							dbg("node","[BROKER] Enqueuing PUBLISH [Dest: %u | Topic: %s | QoS: %u | Payload: %u]\n",
								(n+2),(args[0] == 0) ? "TEMP" : ((args[0] == 1) ? "HUM" : "LUM"), args[2], args[1]);
						} else { 
							dbg("error","[ERROR] PUBLISH enqueuing failed!\n"); 
						}
			
					} 
				}
			}

		}
			
	}

	/**
	*** for every client, it needs to handle the connack, and suback 
	*** connackHandler()
	*** subackHandler()
	**/
	//Handles the receipt of the CONNACK from the BROKER. Stops the reconnect timer and triggers subscribe.
	task void connackHandler(){
		
		AckMessage* ackm=(AckMessage*)connackPayload;

		dbg("node", "[NODE %u] Received CONNACK [Src: %u]\n",TOS_NODE_ID, ackm->clientID);

		state = NODE_CONNECTED;

		call ConnectTimeoutTimer.stop();
		
		// After connection, each node can subscribe to one among these three topics: 
		// TEMPERATURE, HUMIDITY, LUMINOSITY.
		if( subscriptions[0] || subscriptions[1] || subscriptions[2])
			subscribe();

	}

	//Handles receipt of the SUBACK from the BROKER. Stops the resubscribe timer and
	//if the node is configured as a publisher starts the sensing activity.
	task void subackHandler(){

		AckMessage* ackm=(AckMessage*) subackPayload;

		dbg("node", "[NODE %u] Received SUBACK [Src: %u]\n",TOS_NODE_ID, ackm->clientID);

		state = NODE_ACTIVE;

		call SubscribeTimeoutTimer.stop();

	}
	
	//=================== Events =====================//

	event void Boot.booted() {

		uint8_t c;

		if(TOS_NODE_ID == 1){	// BROKER 
			
			for(c = 0; c < N_NODES; c++)
				idProcessed[c] = 0;

			dbg("boot","[BROKER] Application booted.\n");

			state = NODE_ACTIVE;
			
		} else {	// NODE 		

			dbg("boot","[NODE %u] Application booted.\n",TOS_NODE_ID);

			state = NODE_BOOTED;	

			// init topic and qos of subscription and publish
			pubTopic = PUBLICATION_TOPIC[TOS_NODE_ID-2];
			subscriptions[0] = SUBSCRIPTIONS_TOPIC[0][TOS_NODE_ID-2];
			subscriptions[1] = SUBSCRIPTIONS_TOPIC[1][TOS_NODE_ID-2];
			subscriptions[2] = SUBSCRIPTIONS_TOPIC[2][TOS_NODE_ID-2];
			subscriptions[3] = SUBQOS;

			// publish
			if(pubTopic == 0){
				call TimerTemp.startPeriodic(TIME_PERIOD_TEMP);		
			}else if(pubTopic == 1){
				call TimerHum.startPeriodic(TIME_PERIOD_HUM);		
			}else if(pubTopic == 2){
				call TimerLum.startPeriodic(TIME_PERIOD_LUM);		
			}

			// upon activation, each node sends a CONNECT message to the PAN coordinator
			connect();

		}

		// init queue parameters when the queue is empty
		lock = FALSE;
		head = 0;
		tail = 0;
		msgId = 1;
		full = FALSE;
		
		call AMControl.start();

	} 
	
	event void AMControl.startDone(error_t err) {
		if(err == SUCCESS) {

			if(TOS_NODE_ID == 1)
				dbg("comm","[BROKER] Radio on!\n");
			else
				dbg("comm","[NODE %u] Radio on!\n", TOS_NODE_ID); 
		
		} else {

			call AMControl.start();

		}
	}

	event void AMControl.stopDone(error_t err) {
	}

	event void SendTimer.fired(){
		if(head != tail){
			post sendTask();
		}
	}

	//nodes publish temperature after connected successfull
	event void TimerTemp.fired(){
		if(state >= NODE_CONNECTED){
			publish(call Random.rand16()%TEMP_RANGE);	
			//printf("Hi I am publishing to the broker with topic TEMP! \n");
			//printfflush();
		}
	}

	//nodes publish humidity after connected successfull
	event void TimerHum.fired(){
		if(state >= NODE_CONNECTED){
			publish(call Random.rand16()%HUM_RANGE);
			//printf("Hi I am publishing to the broker with topic HUM! \n");
			//printfflush();
		}
		
	}

	//nodes publish luminosity after connected successfull
	event void TimerLum.fired(){
		if(state >= NODE_CONNECTED){
			publish(call Random.rand16()%LUM_RANGE);	
		}
	} 

	event void AMSend.sendDone(message_t* buf,error_t err) {
		
		if(&buffer[head] == buf && err == SUCCESS ) {
		
			// only connect and sub needed to be acknowledged
			if( length[head]==sizeof(PublishMessage) || call PacketAcknowledgements.wasAcked(buf) ){
				
				// remove head to the next one  	
				head = (head+1)%CAPACITY;
				dbg("debug","[NODE %u] SENT queue position %u. New head: %u\n", TOS_NODE_ID, 
					(head == 0) ? (CAPACITY - 1) : head-1, head);

				if(head == tail){	
					full = FALSE;
				}

			} else if(!(call PacketAcknowledgements.wasAcked(buf))){

				dbg("error", "[ERROR] Receiver node FAILED in receiving packet!\n");

			} 

		} else {

			dbg("error", "[ERROR] SEND FAILED \n");

		}

		// relaese the lock
		lock = FALSE;

		// send the next message in the queue
		if(!(call SendTimer.isRunning())){
			call SendTimer.startOneShot(1000);
		}

	}

	event message_t* Receive.receive(message_t* buffer, void* payload, uint8_t len) {
		
		dbg("debug","============ Receiving ============\n");

		if(TOS_NODE_ID == 1){	//BROKER

			dbg("node","the broker receives a message...\n");
			
			switch(len){

				case sizeof(ConnectMessage):

					conPayload = payload;
					post connectionHandler();
					break; 

				case sizeof(SubscribeMessage):

					subPayload = payload;
					post subscriptionHandler();
					break;

				case sizeof(PublishMessage):

					pubPayload = payload;
					post publishHandler();
					break;			

			}

		} else {	//NODE 

			dbg("node","[NODE %d] receives a message...\n", TOS_NODE_ID);

			if(len == sizeof(AckMessage)){

				AckMessage* ackMsg=(AckMessage*)payload;

				switch(ackMsg->code){

					case CONNACK:

						connackPayload = payload;
						post connackHandler();	    	
						break;	

					case SUBACK:

						subackPayload = payload;
						post subackHandler();
						break;
						
				}		
			} else if(len == sizeof(PublishMessage)){

				PublishMessage *pubMsg;	
				uint8_t topic;
		
				pubMsg = (PublishMessage*)pubPayload;
				topic = pubMsg->topicID;

				dbg("node", "[NODE %u] Received MESSAGE [Topic: %s | QoS: %u |Payload: %u]\n",TOS_NODE_ID, \
					(topic == 0) ? "TEMP" : ((topic == 1) ? "HUM" : "LUM"), subscriptions[2*topic+1],payload);

			} else {

				dbg("error", "[ERROR] INVALID PACKET\n");	
		
			}
		
		}	    
		
		return buffer;

	}    
		
	event void ConnectTimeoutTimer.fired(){

		// retransmission if CONN or CONNACK is lost
		if(state == NODE_BOOTED)
			connect();

	}

	event void SubscribeTimeoutTimer.fired(){

		// retransmission if SUB or SUBACK is lost
		if(state == NODE_CONNECTED)
			subscribe();

	}

	
}
