#include "TestFtsp.h"
#include "RadioCountToLeds.h"
#include "printf.h"
#include <Timer.h>
#include "CC2420.h"

#define BEACON 11

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
	bool WAIT_FOR_SYNC = TRUE;
	int count = 0;
	
	// current channel status
	int currentChannel = 0;

	// clock value
	uint32_t loc = 0; 

	// true -> sender/ false -> receiver mode
	bool MODE = TRUE;


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
	event message_t* Receive.receive(message_t* msgPtr, void* payload, uint8_t len)
	{


		// beacon messages
		if (!locked && call PacketTimeStamp.isValid(msgPtr)) {

			radio_count_msg_t* rcm = (radio_count_msg_t*)call Packet.getPayload(msgPtr, sizeof(radio_count_msg_t));
			uint32_t rxTimestamp = call PacketTimeStamp.timestamp(msgPtr);

			call GlobalTime.local2Global(&rxTimestamp);

			// if data packet - toggle led 01
			if( currentChannel != 11 ){
				call Leds.led1Toggle();
				printf("\nDP: <CCH %d> <Count %u>",currentChannel,rcm->counter);
			}

			// if not data packet - toggle led 00
			else{
				call Leds.led0Toggle();
				printf("\nBP: <Count %u>",rcm->counter);
			}

			printfflush();

		}

		return msgPtr;
	}
	//_________________________________________//




	//-----------------------------------------------------//
	event void RadioControl.startDone(error_t err) {
		call LocalClock.startPeriodic(20);
		MODE = FALSE;
		setChannel(BEACON);
		printf("\n<CCH %d> <Booted>",currentChannel);
	}
	//_____________________________________________________//




	//Event called when clock fires
	//-----------------------------------------------------//
	event void LocalClock.fired(){
		
		loc = call LocalClock.getNow();
		call GlobalTime.local2Global(&loc);
		//printf("\n<gC %lu><CCH %d>",loc,currentChannel);

		if(getChannel( ) != currentChannel){
			currentChannel = getChannel();
			//printf("\n<gC %lu><CCH %d>",loc,currentChannel);
			setChannel(currentChannel);
		}

		count++;

		//if sender
		//  construct packet and send
		if( MODE == TRUE && currentChannel != 11)
			sendDataPacket();
		
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

		if( (loc/1000)%10 == 9 || loc < 5000 ){
			return 11;
		}

		if(TOS_NODE_ID % 2 == 0){

			if(band < 5){
				MODE = FALSE;
				return TOS_NODE_ID + 10;
			}

			else{
				MODE = TRUE;
				return TOS_NODE_ID + 11;
			}
		}

		else{

			if(band < 5){
				MODE = TRUE;
				return TOS_NODE_ID + 11;
			}
		
			else{
				MODE = FALSE;
				return TOS_NODE_ID + 10;
			}
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
