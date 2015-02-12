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

	// channel sequence
	int channelSeq[3];
	/*channelSeq[0] = TOS_NODE_ID + 10;
	channelSeq[1] = TOS_NODE_ID + 10 + 5;
	channelSeq[2] = TOS_NODE_ID + 10 + 5 + 3;*/


	//_________________________________________//
	void setChannel(int);
	int getChannel();
	void sendDataPacket(unsigned int);
	int getNextChannel();
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
		if (!locked){

			radio_count_msg_t* rcm = (radio_count_msg_t*)call Packet.getPayload(msgPtr, sizeof(radio_count_msg_t));

			// check if its a data packet or not
			if(currentChannel == BEACON)
				call Leds.led0Toggle();

			else{
				call Leds.led1Toggle();
				pktsReceived++;
				rcount = rcm->counter;
				//setChannel(14);
				setChannel(currentChannel+1);
				sendDataPacket(rcount);
			}
		}

		return msgPtr;
	}
	//_________________________________________//




	//-----------------------------------------------------//
	event void RadioControl.startDone(error_t err) {

		int i=0;

		call LocalClock.startPeriodic(20);
		setChannel(BEACON);
		currentChannel = BEACON;
		printf("\nPackets Received || Packets Sent (updated every second)\n");
		printfflush();

		channelSeq[0] = TOS_NODE_ID + 10;
		channelSeq[1] = TOS_NODE_ID + 10 + 5;
		channelSeq[2] = TOS_NODE_ID + 10 + 5 + 3;

		printf("\nChannel sequence\n");
		printf("Self || NextNode\n");
		for(i=0;i<3;i++)
			printf(" %d\t%d\n",channelSeq[i],channelSeq[i]+1);
		printf("\n");
	}
	//_____________________________________________________//




	//Event called when clock fires
	//-----------------------------------------------------//
	event void LocalClock.fired(){

		// get global clock
		loc = call LocalClock.getNow();
		call GlobalTime.local2Global(&loc);

		// increment count
		count++;

		// update channel if necessary
		if(getChannel() != currentChannel)
			setChannel(getChannel());
		
		// packet statistics
		if(count % 50 == 0){
			printf("\n<CH : %d> %u %u",currentChannel,pktsReceived,pktsSent);
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


		if( loc < 5000 ){
			currentChannel = BEACON;
			return BEACON;
		}

		else{
			int band = (loc/1000)%10; 
			currentChannel = channelSeq[0];
			return channelSeq[0];
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

		call Leds.led2Toggle(); 
		setChannel(getChannel());
		pktsSent++; 
		locked = FALSE; 

		return;
	}

	// channel switch  event
	event void CC2420Config.syncDone(error_t error){ locked = FALSE; return;}
	event void RadioControl.stopDone(error_t error){}
	//_________________________________________//
}
