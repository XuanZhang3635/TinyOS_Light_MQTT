#include "Message.h"
#include "printf.h"

configuration NodeAppC {

} implementation {

  components MainC, NodeC as App, RandomC;

  components new AMSenderC(AM_MY_MSG);
  components new AMReceiverC(AM_MY_MSG);
  components ActiveMessageC;
  //components SerialPrintfC;
  //components SerialStartC;

  components new TimerMilliC() as ConnectTimeoutTimer;
  components new TimerMilliC() as SubscribeTimeoutTimer;
  components new TimerMilliC() as SendTimer;
  components new TimerMilliC() as TimerTemp;
  components new TimerMilliC() as TimerHum;
  components new TimerMilliC() as TimerLum;

  RandomC <- MainC.SoftwareInit;

  App.AMPacket -> AMSenderC;
  App.RadioPacket -> AMSenderC;
  App.Boot -> MainC.Boot;
  App.ConnectTimeoutTimer -> ConnectTimeoutTimer;
  App.SubscribeTimeoutTimer -> SubscribeTimeoutTimer;

  App.Receive -> AMReceiverC;
  App.AMSend -> AMSenderC;
  App.AMControl -> ActiveMessageC;
  App.SendTimer -> SendTimer;
  App.PacketAcknowledgements -> ActiveMessageC;

  App.TimerTemp -> TimerTemp;
  App.TimerHum -> TimerHum;
  App.TimerLum -> TimerLum;
  App.Random -> RandomC;

}
