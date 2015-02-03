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

-[ ] Add int getChannel(uint32_t globalClock) - maps global timestamp to channel
