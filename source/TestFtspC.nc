#include "TestFtsp.h"
#include "RadioCountToLeds.h"
#include "printf.h"
#include <Timer.h>
#include "CC2420.h"

#define BEACON 11

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
	
	// current channel status
	int currentChannel = 0;
	unsigned int pktsSent;

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
	event message_t* Receive.receive(message_t* msgPtr, void* payload, uint8_t len){ return msgPtr; }
	//_________________________________________//




	//-----------------------------------------------------//
	event void RadioControl.startDone(error_t err) {
		call LocalClock.startPeriodic(50);
		setChannel(13);
		printf("\nPackets sent per second\n");
	}
	//_____________________________________________________//




	//Event called when clock fires
	//-----------------------------------------------------//
	event void LocalClock.fired(){
		count++;
		sendDataPacket();

		if(count % 20 == 0)
			printf("\n%d",pktsSent);

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

	}
	//_____________________________________________________//




	//_____________________________________________________//
	void sendDataPacket(){

		radio_count_msg_t* my_data_pkt = (radio_count_msg_t*)call Packet.getPayload(&msg, sizeof(radio_count_msg_t));
		my_data_pkt->counter = count/100;

		if(call AMSend.send(3,&msg,sizeof(radio_count_msg_t)) == SUCCESS) {
			locked = TRUE;
		}
	}
	//_____________________________________________________//




	//_________________________________________//
	event void AMSend.sendDone(message_t* ptr, error_t success) {
		pktsSent++; call Leds.led2Toggle(); locked = FALSE; return;
	}
	// channel switch  event
	event void CC2420Config.syncDone(error_t error){ locked = FALSE; return;}
	event void RadioControl.stopDone(error_t error){}
	//_________________________________________//
}
