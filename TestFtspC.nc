#include "TestFtsp.h"
#include "RadioCountToLeds.h"
#include "printf.h"
#include <Timer.h>
#include "CC2420.h"

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
	int dchan = 16;

	uint32_t switch_time = 0;

	uint32_t loc = 0; 

	int rcount = 0;

	//_________________________________________//

	void setBeaconChannel();
	void setDataChannel();
	void sendDataPacket();
	void updateDataChannel();

	//_________________________________________//

	event void Boot.booted() {
		call RadioControl.start();
	}


	event message_t* Receive.receive(message_t* msgPtr, void* payload, uint8_t len)
	{

		//uint32_t tnow;

		call Leds.led0Toggle();

		// beacon messages
		if (!locked && call PacketTimeStamp.isValid(msgPtr)) {

			radio_count_msg_t* rcm = (radio_count_msg_t*)call Packet.getPayload(msgPtr, sizeof(radio_count_msg_t));
			uint32_t rxTimestamp = call PacketTimeStamp.timestamp(msgPtr);

			/*test_ftsp_msg_t* report = (test_ftsp_msg_t*)call Packet.getPayload(&msg, sizeof(test_ftsp_msg_t));


				report->src_addr = TOS_NODE_ID;
				report->counter = rcm->counter;
				report->local_rx_timestamp = rxTimestamp;
				report->is_synced = call GlobalTime.local2Global(&rxTimestamp);
				report->global_rx_timestamp = rxTimestamp;
				report->skew_times_1000000 = (uint32_t)call TimeSyncInfo.getSkew()*1000000UL;
				report->ftsp_root_addr = call TimeSyncInfo.getRootID();
				report->ftsp_seq = call TimeSyncInfo.getSeqNum();
				report->ftsp_table_entries = call TimeSyncInfo.getNumEntries();*/

			call GlobalTime.local2Global(&rxTimestamp);

			if(rcm->counter <= 200){
				printf("\nDP: %u %lu",rcm->counter,rxTimestamp);
				rcount = rcm->counter;
			}

			else{

				printf("\n%u %lu",rcm->counter,rxTimestamp);
				printfflush();

				WAIT_FOR_SYNC = FALSE;
				count = 0;
				rcount = 0;

				if(TOS_NODE_ID == 3){
					loc = call LocalClock.getNow();
					call GlobalTime.local2Global(&loc);
					printf("\n<ST : %u > <loc : %u >\n",switch_time,loc);
				}

				//updateDataChannel();
				setDataChannel();
			}
		}

		// data packets
		/*

			 else{

			 if(!locked){

		// get payload
		// get count, node_id from payload
		// print <count,node_id> via serial port

		}



		}*/

		return msgPtr;
	}

	event void AMSend.sendDone(message_t* ptr, error_t success) {
		locked = FALSE;
		return;
	}

	//-----------------------------------------------------//
	event void RadioControl.startDone(error_t err) {

		call LocalClock.startPeriodic(20);
		setBeaconChannel();
	}
	//_____________________________________________________//

//Event called when clock fires
	//-----------------------------------------------------//
	event void LocalClock.fired()
	{

		loc = call LocalClock.getNow();
		call GlobalTime.local2Global(&loc);


		if(!WAIT_FOR_SYNC){

			// set time for channel switching - sender
			if(count == 0 && TOS_NODE_ID == 2){
				switch_time = loc + 4000;
			}

			// set time for channel switching - receiver
			if(rcount == 0 && TOS_NODE_ID == 3){
				switch_time = loc + 4000;
			}

			if(loc > switch_time)
				updateDataChannel();
	
				

			setDataChannel();

			if(count > 200){

				setBeaconChannel();
				WAIT_FOR_SYNC = TRUE;
			}
			else{

				count++;

				//if sender
				//  construct packet and send
				if(TOS_NODE_ID == 2){
					printf("\n<Channel : %d> <Count : %u> <Clock : %u>\n",currentChannel,count,loc);
					setDataChannel();
					sendDataPacket();
				}

				else
					printf("\n<Channel : %d> <Count : %u> <Clock : %u>\n",currentChannel,rcount,loc);

			}
			//call Leds.led1Toggle();
		}
	}
	//_____________________________________________________//


	//-----------------------------------------------------//
	void setBeaconChannel(){ 
		currentChannel = 15;
		call CC2420Config.setChannel(15);
		call CC2420Config.sync();

		while(locked);

	}
	void setDataChannel(){ 

		currentChannel = dchan;
		call CC2420Config.setChannel(dchan);
		call CC2420Config.sync();

		while(locked);

	}

	void updateDataChannel(){

		dchan = dchan + 1;

		if(dchan > 20)
			dchan = 16;
	}




	void sendDataPacket(){

		radio_count_msg_t* my_data_pkt = (radio_count_msg_t*)call Packet.getPayload(&msg, sizeof(radio_count_msg_t));
		my_data_pkt->counter = count;

		if(call AMSend.send(AM_BROADCAST_ADDR,&msg,sizeof(radio_count_msg_t)) == SUCCESS) {
			locked = TRUE;
		}
	}

	//_____________________________________________________//



	// channel switch  event
	event void CC2420Config.syncDone(error_t error){ locked = FALSE; return;}


	event void RadioControl.stopDone(error_t error){}
}
