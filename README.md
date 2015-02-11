# Frequency Hopping in WSN using FTSP for time synchronization

## DESCRIPTION:
------------
 The TestFtsp application tests the Flooding Time Synchronization Protocol
 (FTSP) implementation. A network of motes programmed with TestFtsp run the
 FTSP protocol to time synchronize, and sends to the base station the global
 reception timestamps of messages broadcast by a dedicated beacon mote
 programmed with RadioCountToLeds. Ideally, the global reception timestamps of
 the same RadioCountToLeds message should agree for all TestFtsp motes (with a
 small synchronization error).

## TODO:
------------

- [x] Add int getChannel(uint32_t globalClock) - maps global timestamp to channel
- [x] Generalize getChannel( ) for 'n' nodes
- [x] forward each packet 
- [ ] increase channel_switch interval to 500ms, 3rd node receives packets

## Control Flow
------------

	- <startDone> => start local timer LocalClock<20ms>
								=> set beacon channel

	- <LocalClock.fired>
			=> get local time -> convert to global time
			=> check if current channel needs to be updated -> based on current global time
					if so -> update channel
			=> increment counter
			=> check if MODE = 'sender' and channel != 11
					if so -> send data packet(count)

	- <getChannel(global_clock)>
			=> band = 10's digit (ie) 4560 => 10's digit is 6
			=> if 1000's digit == 9 <or> global_clock < 5000
					return channel = beacon_channel
			=> else... based on "band" value -> set MODE as 'sender' or 'receiver'
				=> return channel = TOS_NODE_ID + 10 <or> TOS_NODE_ID + 11 

	- <Receive>
			=> get radio packet
			=> extract timestamp
			=> get global time based on received timestamp
			=> blink LED0 if pkt.counter < 2000 
			=> blink LED1 else


