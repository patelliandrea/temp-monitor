#include "TemperatureMonitor.h"

configuration TemperatureMonitorAppC {}

implementation {
	components TemperatureMonitorC as App;
	components MainC;
	components RandomC;
	components new TimerMilliC() as SinkTimer;
	components new TimerMilliC() as NodeTimer;
	components new TimerMilliC() as WaitTimer;
	components new RandomSensorC() as TempSensor;
	components ActiveMessageC;
	components new AMSenderC(240);
	components new AMReceiverC(240);

	App.Boot -> MainC;
	App.Random -> RandomC;
	App.SinkTimer -> SinkTimer;
	App.NodeTimer -> NodeTimer;
	App.WaitTimer -> WaitTimer;
	App.RawRead -> TempSensor;
	App.AMControl -> ActiveMessageC;
	App.Packet -> AMSenderC;
	App.AMPacket -> AMSenderC;
	App.AMSend -> AMSenderC;
	App.Receive -> AMReceiverC;
}