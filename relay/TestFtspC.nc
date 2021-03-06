#include "TestFtsp.h"
#include "RadioCountToLeds.h"
#include "printf.h"
#include <Timer.h>
#include "CC2420.h"

#define BEACON 11

#define CHANNEL (TOS_NODE_ID+10)

/*

	 [ ] Add a timer - fires every SYNC seconds 
	 [ ] Listen to beacons - when? - switch to beacon channel every SYNC seconds
	 [ ] virtual global clock - fires every SWITCH seconds 
	 [ ] channel switch - beacon -> current -> beacon 

 */
module TestFtspC
{
	uses
	{
		interface GlobalTime<TMilli>;
		interface TimeSyncInfo;
		interface Receive;
		interface AMSend;
		interface Packet;
		interface Leds;
		interface PacketTimeStamp<TMilli,uint32_t>;
		interface Boot;
		interface SplitControl as RadioControl;

		interface Timer<TMilli> as LocalClock;

		// channel switching interfaces
		interface CC2420Packet;
		interface CC2420Config;


	}
}

implementation
{
	message_t msg;
	bool locked = FALSE;

	unsigned int count = 0;
	unsigned int rcount = 0;
	unsigned int pktsReceived = 0;
	unsigned int pktsSent = 0;
	
	// current channel status
	int currentChannel = 0;

	// clock value
	uint32_t loc = 0; 


	//_________________________________________//
	void setChannel(int);
	int getChannel();
	void sendDataPacket(unsigned int);
	//_________________________________________//




	//_________________________________________//

	event void Boot.booted() {
		call RadioControl.start();
	}
	//_________________________________________//




	//_________________________________________//
	event message_t* Receive.receive(message_t* msgPtr, void* payload, uint8_t len)
	{

		call Leds.led1Toggle();

		// beacon messages
		if (!locked){

			radio_count_msg_t* rcm = (radio_count_msg_t*)call Packet.getPayload(msgPtr, sizeof(radio_count_msg_t));

			pktsReceived++;

			rcount = rcm->counter;

			setChannel(CHANNEL+1);
			sendDataPacket(rcount);
		}

		return msgPtr;
	}
	//_________________________________________//




	//-----------------------------------------------------//
	event void RadioControl.startDone(error_t err) {
		call LocalClock.startPeriodic(20);
		setChannel(CHANNEL);
		printf("\nPackets Received || Packets Sent per second\n");
		printfflush();
	}
	//_____________________________________________________//




	//Event called when clock fires
	//-----------------------------------------------------//
	event void LocalClock.fired(){
		count++;
		if(count % 50 == 0){
			printf("\n%u %u",pktsReceived,pktsSent);
			printfflush();
		}
		
	}
//_____________________________________________________//




	//-----------------------------------------------------//
	void setChannel(int chan){ 
		currentChannel = chan;
		call CC2420Config.setChannel(chan);
		call CC2420Config.sync();
		//while(locked);
	}
	//_____________________________________________________//




	//-----------------------------------------------------//
	int  getChannel( ){ 

		int band = (loc/10)%10; 

		if( (loc/1000)%10 == 9 || loc < 5000 )
			return 11;

		if(TOS_NODE_ID == 2){

			if(band < 5)
				return TOS_NODE_ID + 10;

			else
				return TOS_NODE_ID + 11;
		}

		else{

			if(band < 5)
				return TOS_NODE_ID + 11;
		
			else
				return TOS_NODE_ID + 10;
		}

	}
	//_____________________________________________________//




	//_____________________________________________________//
	void sendDataPacket(unsigned int value){

		radio_count_msg_t* my_data_pkt = (radio_count_msg_t*)call Packet.getPayload(&msg, sizeof(radio_count_msg_t));
		my_data_pkt->counter = value;

		if(call AMSend.send(TOS_NODE_ID+1,&msg,sizeof(radio_count_msg_t)) == SUCCESS) {
			//locked = TRUE;
		}
	}
	//_____________________________________________________//




	//_________________________________________//
	event void AMSend.sendDone(message_t* ptr, error_t success) {

		setChannel(CHANNEL);
		call Leds.led2Toggle(); 
		pktsSent++; 
		locked = FALSE; 

		return;
	}

	// channel switch  event
	event void CC2420Config.syncDone(error_t error){ locked = FALSE; return;}
	event void RadioControl.stopDone(error_t error){}
	//_________________________________________//
}
