#include "TestFtsp.h"
#include "RadioCountToLeds.h"
#include "printf.h"
#include <Timer.h>
#include "CC2420.h"

#define BEACON 11
#define CHANNEL (TOS_NODE_ID+ 10)

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
	int count = 0;
	unsigned int pktsReceived;
	
	// current channel status
	int currentChannel = 0;

	// clock value
	uint32_t loc = 0; 


	//_________________________________________//
	void setChannel(int);
	int getChannel();
	void sendDataPacket();
	//_________________________________________//




	//_________________________________________//

	event void Boot.booted() {
		call RadioControl.start();
	}
	//_________________________________________//




	//_________________________________________//
	event message_t* Receive.receive(message_t* msgPtr, void* payload, uint8_t len){

		/*radio_count_msg_t* rcm = (radio_count_msg_t*)call Packet.getPayload(msgPtr, sizeof(radio_count_msg_t));
			uint32_t rxTimestamp = call PacketTimeStamp.timestamp(msgPtr);
			call GlobalTime.local2Global(&rxTimestamp);*/

		pktsReceived++;
		call Leds.led1Toggle();
		return msgPtr;

	}
	//_________________________________________//




	//-----------------------------------------------------//
	event void RadioControl.startDone(error_t err) {
		pktsReceived = 0;
		call LocalClock.startPeriodic(1000);
		setChannel(CHANNEL);
		printf("\nPackets received per second\n");
		printfflush();
	}
	//_____________________________________________________//




	//Event called when clock fires
	//-----------------------------------------------------//
	event void LocalClock.fired(){ 
		printf("\n%d",pktsReceived); 
		pktsReceived = 0;
		printfflush();
	}
//_____________________________________________________//




	//-----------------------------------------------------//
	void setChannel(int chan){ 
		currentChannel = chan;
		call CC2420Config.setChannel(chan);
		call CC2420Config.sync();
		while(locked);
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
	void sendDataPacket(){

		radio_count_msg_t* my_data_pkt = (radio_count_msg_t*)call Packet.getPayload(&msg, sizeof(radio_count_msg_t));
		my_data_pkt->counter = count;

		if(call AMSend.send(AM_BROADCAST_ADDR,&msg,sizeof(radio_count_msg_t)) == SUCCESS) {
			locked = TRUE;
		}
	}
	//_____________________________________________________//




	//_________________________________________//
	event void AMSend.sendDone(message_t* ptr, error_t success) {
		locked = FALSE; return;
	}
	// channel switch  event
	event void CC2420Config.syncDone(error_t error){ locked = FALSE; return;}
	event void RadioControl.stopDone(error_t error){}
	//_________________________________________//
}
