#ifndef TEMPMONITOR_H
#define TEMPMONITOR_H

enum {
	MOTES = 10,
	LAST_READS = 6,
	READ_PERIOD = 5120,
	SINK_PERIOD = 10240
};

typedef nx_struct AverageMessage {
	nx_uint16_t idRequest;
	nx_uint32_t average;
} AverageMessage;

typedef nx_struct AverageRequestMessage {
	nx_uint16_t idNode;
	nx_uint16_t idRequest;
} AverageRequestMessage;

typedef nx_struct NotReadyMessage {
	nx_uint16_t idRequest;
} NotReadyMessage;

#endif