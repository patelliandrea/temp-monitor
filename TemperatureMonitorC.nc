#include "TemperatureMonitor.h"

module TemperatureMonitorC {
	uses interface Boot;
	uses interface Random;
	uses interface Timer<TMilli> as NodeTimer;
	uses interface Timer<TMilli> as SinkTimer;
	uses interface Timer<TMilli> as WaitTimer;
	uses interface Read<uint16_t> as RawRead;
	uses interface Packet;
	uses interface AMPacket;
	uses interface AMSend;
	uses interface Receive;
	uses interface SplitControl as AMControl;
}

implementation {
	uint16_t lastValues[LAST_READS];	// last (6) reads
	uint8_t readsCount = 0;	// read count, 0, 1, 2, 3, 4, 5, 6, 0 , ...
	bool ready = FALSE;	// TRUE if the sensor has read 6 values
	bool busy = FALSE;	// TRUE if the sensor is sending a message
	message_t packet;
	uint16_t idRequest = 0; // id of the request the sink is making
	uint16_t request;	// id of the request received by the sensor

	float avg() {
		float sum = 0;
		uint8_t i;
		for(i = 0; i < LAST_READS; i++) {
			sum += lastValues[i];
		}
		return sum / LAST_READS;
	}

	bool isSinkNode() {
		return TOS_NODE_ID == 0;
	}

	// if readsCount == 0 then the sensor has read 6 values
	void checkReady() {
		if(readsCount == 0) {
			ready = TRUE;
		} else {
			ready = FALSE;
		}
	}

	// sink has to choose a random sensor
	uint16_t chooseRandomSensor() {
		// single sensor or broadcast, 33% broadcast, 66% single sensor
		uint16_t randomN = call Random.rand16() % 3;
		if(randomN == 0) {
			dbg("default", "request %d | broadcast\n", idRequest);
			// return broadcast address
			return TOS_BCAST_ADDR;
		} else {
			// return random sensor id
			uint16_t idNode = (call Random.rand16() % (MOTES - 1)) + 1;
			dbg("default", "request %d | node %d\n", idRequest, idNode);
			return idNode;
		}
	}

	// request made by the sink
	task void sendRequestToNode() {
		if(!busy) {
			AverageRequestMessage *message = (AverageRequestMessage *)(call Packet.getPayload(&packet, sizeof(AverageRequestMessage)));
			message->idNode = chooseRandomSensor();	// address of the sensor
			message->idRequest = idRequest;	// id of the request (for debugging purposes)
			// if the request is succesfully sent, increase id Request, busy until sendDone
			if(call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(AverageRequestMessage)) == SUCCESS) {
				idRequest++;
				busy = TRUE;
			} else {
				// error, send request again
				dbg("default", "trying again to send request to node");
				post sendRequestToNode();
			}
		}
	}

	error_t sendAverageToSink() {
		uint32_t average;
		AverageMessage *message = (AverageMessage *)(call Packet.getPayload(&packet, sizeof(AverageMessage)));
		if(message == NULL) {
			return FAIL;
		}
		// compute the average
		*(float*)&average = avg();
		dbg("default", "request %d | sending %f\n", request, *(float*)&average);
		message->average = average;
		message->idRequest = request;
		// try to send the message, busy until sendDone
		if(call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(AverageMessage)) == SUCCESS) {
			busy = TRUE;
			return SUCCESS;
		} else {
			dbg("debug", "Error in sending average to sink");
			return FAIL;
		}
	}

	error_t sendNotReadyToSink() {
		NotReadyMessage *message = (NotReadyMessage *)(call Packet.getPayload(&packet, sizeof(NotReadyMessage)));
		if(message == NULL) {
			return FAIL;
		}
		message->idRequest = request;
		if(call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(NotReadyMessage)) == SUCCESS) {
			busy = TRUE;
			return SUCCESS;
		} else {
			dbg("debug", "Error in sending not ready message to sink");
			return FAIL;
		}
	}

	// if the sensor is ready, sendAverageToSink, if not ready sendNotReadyToSink()
	void sendMessage() {
		if(!busy) {
			error_t result;
			if(ready) {
				result = sendAverageToSink();
				// try to send the message until it is successfully sent
				while(result != SUCCESS) {
					result = sendAverageToSink();
				}
			} else {
				result = sendNotReadyToSink();
				while(result != SUCCESS) {
					result = sendNotReadyToSink();
				}
			}
		}
	}

	event void Boot.booted() {
		call AMControl.start();
	}

	event void AMControl.startDone(error_t err) {
		if(err == SUCCESS) {
			if(isSinkNode()) {
				// if the current sensor is the sink, start the sink timer
				call SinkTimer.startPeriodic(SINK_PERIOD);
			} else {
				// otherwise start the node timer
				call NodeTimer.startPeriodic(READ_PERIOD);
			}
		} else {
			// error
			call AMControl.start();
		}
	}

	event void AMControl.stopDone(error_t err) {}

	// every 5 second, read the temperature
	event void NodeTimer.fired() {
		call RawRead.read();
	}

	// after the random delay, sendMessage
	event void WaitTimer.fired() {
		sendMessage();
	}

	// when the sink timer is fired, send request to random sensor or broadcast
	event void SinkTimer.fired() {
		post sendRequestToNode();
	}

	event void RawRead.readDone(error_t result, uint16_t val) {
		if(result == SUCCESS) {
			// if the sensor has already read LAST_READS values, readsCount = 0
			readsCount = readsCount + 1 > (LAST_READS - 1) ?  0 : readsCount + 1;
			lastValues[readsCount] = val;

			if(!ready) {
				checkReady();
			}
		} else {
			dbg("debug", "error in readDone");
			// error
		}
	}

	// the message was successfully sent, busy = FALSE
	event void AMSend.sendDone(message_t *msg, error_t err) {
		if(&packet == msg) {
			busy = FALSE;
		}
		if(err != SUCCESS) {
			dbg("debug", "error in sendDone");
			// error
		}
	}

	// when a node receive a message
	event message_t* Receive.receive(message_t *msg, void *payload, uint8_t len) {
		am_addr_t sourceAddress;
		uint32_t average;
		uint16_t node;

		if(len == sizeof(NotReadyMessage) && isSinkNode()) {
			// the queried sensor is not ready
			NotReadyMessage *message = (NotReadyMessage *) payload;
			sourceAddress = call AMPacket.source(msg);
			dbg("default", "request %d failed | node %d | not ready\n", message->idRequest, sourceAddress);
		} else if(len == sizeof(AverageMessage) && isSinkNode()) {
			// the queried sensor responded with the average temperature
			AverageMessage *message = (AverageMessage *) payload;
			sourceAddress = call AMPacket.source(msg);
			average = message->average;
			dbg("default", "request %d succeed | node %d | average: %f\n", message->idRequest, sourceAddress, *(float*)&average);
		} else if(len == sizeof(AverageRequestMessage) && !isSinkNode()) {
			// the sink requested the average temperature
			AverageRequestMessage *message = (AverageRequestMessage *) payload;
			sourceAddress = call AMPacket.source(msg);
			request = message->idRequest;

			node = message->idNode;
			// if request to single sensor
			if(node == TOS_NODE_ID) {
				if(call WaitTimer.isRunning()) {
					call WaitTimer.stop();
				}
				// reply
				sendMessage();
			} else if(node == TOS_BCAST_ADDR) {
				// if broadcast, compute random delay and reply when WaitTimer.fired()
				uint16_t delay = call Random.rand16() % 200;
				call WaitTimer.startOneShot(delay);
			} else {
				//
			}
		}
		return msg;
	}
}































