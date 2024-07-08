MODULE_NAME='mAmxCeRel8'    (
                                dev vdvObject,
                                dev dvPort
                            )

(***********************************************************)
#DEFINE USING_NAV_MODULE_BASE_CALLBACKS
#DEFINE USING_NAV_MODULE_BASE_PROPERTY_EVENT_CALLBACK
#DEFINE USING_NAV_MODULE_BASE_PASSTHRU_EVENT_CALLBACK
#DEFINE USING_NAV_STRING_GATHER_CALLBACK
#include 'NAVFoundation.ModuleBase.axi'
#include 'NAVFoundation.SocketUtils.axi'
#include 'NAVFoundation.ArrayUtils.axi'
#include 'NAVFoundation.StringUtils.axi'
#include 'LibAmxCeInterface.axi'

/*
 _   _                       _          ___     __
| \ | | ___  _ __ __ _  __ _| |_ ___   / \ \   / /
|  \| |/ _ \| '__/ _` |/ _` | __/ _ \ / _ \ \ / /
| |\  | (_) | | | (_| | (_| | ||  __// ___ \ V /
|_| \_|\___/|_|  \__, |\__,_|\__\___/_/   \_\_/
                 |___/

MIT License

Copyright (c) 2023 Norgate AV Services Limited

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

constant char DELIMITER[] = {NAV_LF_CHAR}

constant long TL_SOCKET_CHECK   = 1
constant long TL_HEARTBEAT      = 2

constant integer RELAY_CHANNELS[] = { 1, 2, 3, 4, 5, 6, 7, 8 }

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile long socketCheck[] =   { 3000 }
volatile long heartbeat[] = { 20000 }

volatile _NAVStateBoolean state[8]

(***********************************************************)
(*               LATCHING DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_LATCHING

(***********************************************************)
(*       MUTUALLY EXCLUSIVE DEFINITIONS GO BELOW           *)
(***********************************************************)
DEFINE_MUTUALLY_EXCLUSIVE

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)
(* EXAMPLE: DEFINE_FUNCTION <RETURN_TYPE> <NAME> (<PARAMETERS>) *)
(* EXAMPLE: DEFINE_CALL '<NAME>' (<PARAMETERS>) *)

define_function SendString(char payload[]) {
    payload = "payload, NAV_LF"

    NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_TO,
                                            dvPort,
                                            payload))

    send_string dvPort, "payload"
    wait 1 module.CommandBusy = false
}


define_function MaintainSocketConnection() {
    if (module.Device.SocketConnection.IsConnected) {
        return
    }

    NAVClientSocketOpen(module.Device.SocketConnection.Socket,
                        module.Device.SocketConnection.Address,
                        module.Device.SocketConnection.Port,
                        IP_TCP)
}


#IF_DEFINED USING_NAV_STRING_GATHER_CALLBACK
define_function NAVStringGatherCallback(_NAVStringGatherResult args) {
    stack_var char data[NAV_MAX_BUFFER]
    stack_var char delimiter[NAV_MAX_CHARS]

    stack_var char type[NAV_MAX_CHARS]
    stack_var char path[NAV_MAX_CHARS]
    stack_var integer relay
    stack_var char key[NAV_MAX_CHARS]
    stack_var char value

    data = args.Data
    delimiter = args.Delimiter

    NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_PARSING_STRING_FROM,
                                            dvPort,
                                            data))

    data = NAVStripRight(data, length_array(delimiter))

    type = NAVStripRight(remove_string(data, ' ', 1), 1)

    remove_string(data, ':', 1)
    path = NAVGetStringBetween(data, '"', '"')
    remove_string(data, ',', 1)

    // NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
    //             "'mAmxCeRel8 => Type: ', type, ' Path: ', path")

    relay = atoi(NAVGetStringBetween(path, '/relay/', '/'))

    // key = NAVGetStringBetween(remove_string(data, ':', 1), '"', '"')

    // NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
    //             "'mAmxCeRel8 => Key: ', key")

    // if (!length_array(key)) {
    //     return
    // }

    // if (NAVContains(key, 'error')) {
    //     NAVErrorLog(NAV_LOG_LEVEL_ERROR,
    //                 "'mAmxCeRel8 => Error: ', NAVGetStringBetween(data, '"', '"')")

    //     return
    // }

    switch (type) {
        case '@get': {
            switch (relay) {
                case 8: {
                    // Heartbeat response
                    if (module.Device.IsInitialized) {
                        return
                    }

                    Init()
                }
            }
        }
        // case '@set': {}
        // case '@exec': {}
        // case '@subscribe': {}
        // case 'publish': {
        //     remove_string(data, '"value":', 1)
        //     value = NAVStringToBoolean(NAVStripRight(data, 1))
        //     state[relay].Actual = value

        //     NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
        //                 "'mAmxCeRel8 => Relay ', itoa(relay), ' : ', NAVBooleanToString(value)")
        // }
        // default: {
        //     // Probably an error message
        //     NAVErrorLog(NAV_LOG_LEVEL_ERROR,
        //                 "'mAmxCeRel8 => Error: ', NAVStripRight(args.Data, length_array(args.Delimiter))")
        // }
    }
}
#END_IF


define_function Init() {
    stack_var integer x

    for (x = 1; x <= 8; x++) {
        SendString(BuildRelayCommand(COMMAND_TYPE_SUBSCRIBE, x, ''))
    }

    module.Device.IsInitialized = true
}


define_function CommunicationTimeOut(integer timeout) {
    cancel_wait 'TimeOut'

    module.Device.IsCommunicating = true

    wait (timeout * 10) 'TimeOut' {
        module.Device.IsCommunicating = false
    }
}


define_function Reset() {
    module.Device.SocketConnection.IsConnected = false
    module.Device.IsCommunicating = false
    module.Device.IsInitialized = false

    NAVTimelineStop(TL_HEARTBEAT)
}


define_function NAVModulePropertyEventCallback(_NAVModulePropertyEvent event) {
    switch (event.Name) {
        case NAV_MODULE_PROPERTY_EVENT_IP_ADDRESS: {
            module.Device.SocketConnection.Address = NAVTrimString(event.Args[1])
            module.Device.SocketConnection.Port = HCONTROL_IP_PORT

            NAVTimelineStart(TL_SOCKET_CHECK,
                                socketCheck,
                                TIMELINE_ABSOLUTE,
                                TIMELINE_REPEAT)
        }
    }
}


define_function NAVModulePassthruEventCallback(_NAVModulePassthruEvent event) {
    if (event.Device != vdvObject) {
        return
    }

    SendString(event.Payload)
}


define_function HandleChannelEvent(integer channel, char state) {
    if (!module.Device.SocketConnection.IsConnected) {
        return
    }

    if (!module.Device.IsInitialized) {
        return
    }

    if (state) {
        NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                    "'mAmxCeRel8 => Channel ', itoa(channel), ' Triggered: On'")

        SendString(BuildRelayCommand(COMMAND_TYPE_SET,
                                            channel,
                                            NAVBooleanToString(true)))
    }
    else {
        NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                    "'mAmxCeRel8 => Channel ', itoa(channel), ' Triggered: Off'")

        SendString(BuildRelayCommand(COMMAND_TYPE_SET,
                                            channel,
                                            NAVBooleanToString(false)))
    }
}


(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START {
    create_buffer dvPort, module.RxBuffer.Data
    module.Device.SocketConnection.Socket = dvPort.PORT
}

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

data_event[dvPort] {
    online: {
        NAVErrorLog(NAV_LOG_LEVEL_INFO,
                    "'mAmxCeRel8 => [', NAVDeviceToString(data.device), ']: Online'")

        module.Device.SocketConnection.IsConnected = true

        NAVTimelineStart(TL_HEARTBEAT,
                            heartbeat,
                            TIMELINE_ABSOLUTE,
                            TIMELINE_REPEAT)
    }
    offline: {
        NAVErrorLog(NAV_LOG_LEVEL_INFO,
                    "'mAmxCeRel8 => [', NAVDeviceToString(data.device), ']: Offline'")

        NAVClientSocketClose(data.device.port)
        Reset()
    }
    onerror: {
        NAVErrorLog(NAV_LOG_LEVEL_ERROR,
                    "'mAmxCeRel8 => [', NAVDeviceToString(data.device), ']: OnError : ', NAVGetSocketError(type_cast(data.number))")

        Reset()
    }
    string: {
        CommunicationTimeOut(30)

        NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                    NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_FROM,
                                                data.device,
                                                data.text))

        select {
            active (true): {
                NAVStringGather(module.RxBuffer, DELIMITER)
            }
        }
    }
}


data_event[vdvObject] {
    online: {
        NAVCommand(data.device, "'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_DESCRIPTION,Relay Interface'")
        NAVCommand(data.device, "'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_MANUFACTURER_URL,amx.com'")
        NAVCommand(data.device, "'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_MANUFACTURER_NAME,AMX'")
    }
}


channel_event[vdvObject, RELAY_CHANNELS] {
    on: {
        HandleChannelEvent(channel.channel, true)
    }
    off: {
        HandleChannelEvent(channel.channel, false)
    }
}


timeline_event[TL_SOCKET_CHECK] { MaintainSocketConnection() }


timeline_event[TL_HEARTBEAT] {
    SendString(BuildRelayCommand(COMMAND_TYPE_GET, 8, ''))
}


timeline_event[TL_NAV_FEEDBACK] {
    [vdvObject, NAV_IP_CONNECTED]	= (module.Device.SocketConnection.IsConnected)
    [vdvObject, DEVICE_COMMUNICATING] = (module.Device.IsCommunicating)
    [vdvObject, DATA_INITIALIZED] = (module.Device.IsInitialized)
}


(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)
