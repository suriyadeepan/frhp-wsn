#include "TestFtsp.h"
#include "RadioCountToLeds.h"
#include "printf.h"
#include <Timer.h>
#include "CC2420.h"

#define BEACON 11

#define FHOP_COUNT 4

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


	int mCh[FHOP_COUNT];
	int nCh[FHOP_COUNT];




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

			setChannel(nCh[rcount%4]);

			rcount = rcm->counter;

			sendDataPacket(rcount);

		}

		return msgPtr;
	}
	//_________________________________________//




	//-----------------------------------------------------//
	event void RadioControl.startDone(error_t err) {

		int i=0;

		call LocalClock.startPeriodic(20);
		setChannel(CHANNEL);

		mCh[0] = TOS_NODE_ID + 10;

		if(TOS_NODE_ID == 3){
			mCh[1] = TOS_NODE_ID + 10;
			mCh[2] = TOS_NODE_ID + 10;
			mCh[3] = TOS_NODE_ID + 10;
		}
		
		else{
			mCh[1] = TOS_NODE_ID + 10 + 4;
			mCh[2] = mCh[1] + 3;
			mCh[3] = mCh[2] + 3;
		}

		nCh[0] = TOS_NODE_ID + 10 + 1;
		nCh[1] = TOS_NODE_ID + 10 + 5;
		nCh[2] = nCh[1]+3;
		nCh[3] = nCh[2]+3;

		printf("\nmy_channel || next_channel\n");
		for(i=0;i<FHOP_COUNT;i++)
			printf("%d %d\n",mCh[i],nCh[i]);
		printf("\n");

		printf("\nPackets Received || Packets Sent || Last packet value -  per second\n");
		printfflush();
		
	}
	//_____________________________________________________//




	//Event called when clock fires
	//-----------------------------------------------------//
	event void LocalClock.fired(){
		count++;
		if(count % 50 == 0){
			printf("\n%u %u %u @%d",pktsReceived,pktsSent,rcount,currentChannel);
			printfflush();
			pktsReceived = 0;
			pktsSent = 0;
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

		setChannel(mCh[rcount%4]);
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
