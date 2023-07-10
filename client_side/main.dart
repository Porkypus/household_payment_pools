import 'dart:collection';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:confetti/confetti.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

//comment so github can detect changes

class MyApp extends StatelessWidget {

  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        textTheme: TextTheme(
            bodyText2: TextStyle(fontSize:20)
        ),
        primarySwatch: Colors.blue,
      ),
      home: const LoadingPage(),
    );
  }
}

class Request {
  String type;
  List<String> fields;
  Function(Response response) onReply;

  Request(this.type, this.fields, this.onReply);

  String instantiate(int requestID) {
    if (fields.isNotEmpty) {
      return "<REQUEST,REQUESTID:"+requestID.toString()+","+type+","+fields.join(",")+">";
    } else {
      return "<REQUEST,REQUESTID:"+requestID.toString()+","+type+">";
    }
  }
}

class StaticRequest {
  String type;
  List<String> fields;

  StaticRequest(this.type, this.fields);

  Request toRequest(Function (Response response) onReply) {
    return Request(type, fields, onReply);
  }
}

class Response {
  String type;
  List<String> fields;

  Response(this.type, this.fields);
}

class Message {
  String message;

  Message(this.message);

  String toPacketString() {
    return message;
  }
}

class GroupNameAndId {
  String groupName;
  String groupID;

  GroupNameAndId(this.groupName, this.groupID);
}

class ConnectionState {
  String protocolState = "CONNECTING";
  // Possible states:
  // CONNECTING (not connected, trying to connect to server)
  // HANDSHAKE1 (waiting for HOUSEPAYSERVER)
  // HANDSHAKE2 (waiting for HANDSHAKESUCCESSFUL)
  // WAITING (waiting for responses)
  // IDLE (connected but not waiting)
  String userID = "";
  String dataIn = "";
  int requestNumber = 1;
  bool insidePacket = false;
  bool insideString = false;
  int waitingPackets = 0;
  bool currentlyLoggedIn = false;
  bool isEnded = false;
}

class PersistentProtocolConnection {
  String host = "";
  int port = -1;
  Duration waitBeforeRetry = const Duration(seconds:2);

  late Socket socket;
  late Function onNotification;

  ConnectionState connectionState = ConnectionState();

  bool hasLoginData = false;
  bool isInLoggedInPartsOfApp = false;
  bool spontaneousLogOut = false;
  String username = "";
  String password = "";
  String encryptedPassword = "";
  String userID = "";

  Queue<Request> toSend = Queue<Request>();
  Map<int, Request> waitingRequests = <int, Request>{};

  Map<String, PersistentWidgetState> persistentStates = <String, PersistentWidgetState>{};

  static int instanceCount = 0;

  static final PersistentProtocolConnection _persistentProtocolConnection = PersistentProtocolConnection._internal("143.47.226.197", 25565, () => 5);

  PersistentProtocolConnection._internal(String hostname, int portnumber, this.onNotification) {
    host = hostname;
    port = portnumber;
    instanceCount++;
    connect();
  }

  factory PersistentProtocolConnection() {
    return _persistentProtocolConnection;
  }

  PersistentWidgetState stateFromID(String stateIdentifier) {
    PersistentWidgetState? state = persistentStates[stateIdentifier];
    if (state != null) {
      return state;
    } else {
      PersistentWidgetState newState = PersistentWidgetState();
      persistentStates[stateIdentifier] = newState;
      return newState;
    }
  }

  void wipeStateWithID(String stateIdentifier) {
    persistentStates.remove(stateIdentifier);
  }

  void saveToDisk(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(key, value);
  }

  Future<String?> getFromDisk(String key) async {

    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(key);
  }

  void connect() async {
    print("connecting...");
    try {
      socket = await Socket.connect(host, port, timeout: const Duration(seconds: 30));
    } on SocketException {
      connect();
      return;
    }

    print("connected.");
    connectionState.protocolState = "HANDSHAKE1";
    sendRawText("<HOUSEPAYCLIENT>");

    socket.listen (
        onDataReceive,

        onError: (error) async {
          if (!connectionState.isEnded) {
            connectionState.isEnded = true;
            print(error);
            print("reconnecting on error");
            socket.destroy();
            saveLostRequests();
            await Future.delayed(waitBeforeRetry);
            connectionState = ConnectionState();
            connect();
          } else {
            print("had an error, but it's already handled");
          }

        },

        onDone: () async {
          if (!connectionState.isEnded) {
            connectionState.isEnded = true;
            print("reconnecting on server leaving");
            socket.destroy();
            saveLostRequests();
            connectionState = ConnectionState();
            await Future.delayed(waitBeforeRetry);
            connect();
          } else {
            print("onDone() called, but it's already handled");
          }
        }
    );
  }

  void saveLostRequests() {
    for (Request request in waitingRequests.values) {
      toSend.add(request);
    }
    waitingRequests.clear();
  }

  void addRequestToQueue(Request request) {
    toSend.add(request);
  }

  void sendDebugMessage(String message) async {
    print("Debug message to server: "+message);
    sendRawText("<DEBUG,\""+message+"\">");
  }

  void addMessageToQueue(Request request) {
    print("adding to request queue");
    toSend.add(request);
  }

  void sendRawText(String text) {
    socket.write(text);
    print("just written the raw text "+text+" to the server");
  }

  void addAndSendRequest(Request request){
    addRequestToQueue(request);
    if (connectionState.protocolState == "IDLE" || connectionState.protocolState == "WAITING") {
      sendRequestsFromQueue();
    }
  }

  void sendRelogRequest(Request request) {
    socket.write(request.instantiate(connectionState.requestNumber));
    waitingRequests[connectionState.requestNumber] = request;
    connectionState..requestNumber+=1
      ..waitingPackets+=1;
    print("(Relog) Client to server: "+request.instantiate(connectionState.requestNumber-1));
  }

  void sendRequestsFromQueue() {
    String messages = "";
    while (toSend.isNotEmpty) {
      Request request = toSend.removeFirst();
      messages += request.instantiate(connectionState.requestNumber);
      waitingRequests[connectionState.requestNumber] = request;
      connectionState..requestNumber+=1
        ..protocolState = "WAITING"
        ..waitingPackets+=1;
    }
    if (messages != "") {
      print("Client to server: $messages");
      socket.write(messages);
    }
  }

  void onDataReceive(Uint8List data) {
    String stringData = String.fromCharCodes(data);
    for (String char in stringData.characters) {
      if (char == "<" && !connectionState.insideString) {
        if (connectionState.insidePacket) {
          sendDebugMessage("Potential malformed packet: found '<' inside packet, not enclosed in a string");
        }
        connectionState.insidePacket = true;
        connectionState.dataIn = "<";
      }
      if (connectionState.insidePacket) {
        connectionState.dataIn += char;
        if (char == '"') {
          connectionState.insideString = !connectionState.insideString;
        }
      } else {
      }
      if (char == ">" && !connectionState.insideString) {
        if (!connectionState.insidePacket) {
          sendDebugMessage("Potential malformed packet: found '>' outside a packet, not enclosed in a string");
        }
        connectionState.dataIn += ">";
        connectionState.insidePacket = false;
        onPacketReceive(connectionState.dataIn);
      }
    }
  }

  List<String> splitPreservingStrings(String string) {
    List<String> strings = [];
    String currentString = "";
    bool insideString = false;
    for (String char in string.characters) {
      if (char == '"') {
        insideString = !insideString;
      }
      if (insideString || char != ",") {
        currentString += char;
      } else {
        strings.add(currentString);
        currentString = "";
      }
    }
    strings.add(currentString);
    return strings;
  }

  onPacketReceive(String packet) {
    List<String> pack = splitPreservingStrings(packet);

    //remove angle brackets
    pack[0] = pack[0].substring(2);
    pack[pack.length - 1] = pack[pack.length - 1].substring(0,pack[pack.length-1].length - 2);

    for (int i = 0; i < pack.length; i++) {
      //trim whitespace
      pack[i] = pack[i].trim();
    }

    print("received packet:");
    print(pack);

    // Types of packets the server can send:
    //  - <HOUSEPAYSERVER>
    //  - <DEBUG,"message">
    //  - <HANDSHAKESUCCESSFUL>
    //    (We can ignore HANDSHAKEFAIL, we autoreconnect)
    //  - <RESPONSE,REQUESTID:number,REQUESTTYPE,...>
    //  - <NOTIFICATION,NOTIFICATIONTYPE,NOTIFICATIONID:number,"title","body",TIMESTAMP:unixseconds,"item1"."item2"."item3"...>

    switch (pack[0]) {
      case "HOUSEPAYSERVER":
        {
          print("received HOUSEPAYSERVER: current state is "+connectionState.protocolState);
          if (!(connectionState.protocolState == "CONNECTING" || connectionState.protocolState == "HANDSHAKE1")) {
            sendDebugMessage("Client somehow received a HOUSEPAYSERVER after already completing this handshake step");
          }
          connectionState.protocolState = "HANDSHAKE2";
          print("set state to handshake2");
          sendRawText("<HANDSHAKESUCCESSFUL>");
          print("sent HANDSHAKESUCCESSFUL to server");
        }
        break;
      case "DEBUG": {
        if (pack.length > 1) {
          print("Received debug message from server: "+pack[1]);
        } else {
          print("Received empty debug message from server");
          // We can't send the server debug messages about debug messages, because otherwise we might start an infinite back-and-forth
        }
      }
      break;
      case "HANDSHAKESUCCESSFUL": {
        print("received HANDSHAKESUCCESSFUL: current state is "+connectionState.protocolState);
        if (connectionState.protocolState == "CONNECTING" || connectionState.protocolState == "HANDSHAKE1") {
          connectionState.protocolState = "IDLE";
          sendDebugMessage("Client received HANDSHAKESUCCESSFUL a little early - it looks like the server skipped a step or two");
          //ready to start sending requests
          sendRequestsFromQueue();
        } else {
          if (connectionState.protocolState != "HANDSHAKE2") {
            sendDebugMessage("Client received a HANDSHAKESUCCESSFUL packet but remembers already completing the handshake");
          } else {
            //state was handshake1
            //we might have lost connection and got logged out, so immediately relog
            if (isInLoggedInPartsOfApp && hasLoginData) {
              print("lost connection, relogging");
              sendRelogRequest(Request("LOGIN", ['USERNAME:"'+username+'"','PASSWORD:"'+encryptedPassword+'"'], (response) {
                if (response.fields.length == 2 && response.fields[0]=="SUCCESS") {
                  //ready to start sending requests
                  connectionState.protocolState = "IDLE";
                  print("relog succeeded, resuming");
                  sendRequestsFromQueue();
                } else {
                  //relog failed somehow, stored details must be wrong
                  username = "";
                  password = "";
                  encryptedPassword = "";
                  hasLoginData = false;
                  saveToDisk("ENCRYPTEDPASSWORD", "");
                  spontaneousLogOut = true;

                  //may as well let remaining requests through
                  connectionState.protocolState = "IDLE";
                  print("relog failed, spontaneously quitting");
                  sendRequestsFromQueue();
                }
              }));
            } else {
              print("did not relog, becuase "+hasLoginData.toString()+" and "+isInLoggedInPartsOfApp.toString());
              //ready to start sending requests
              connectionState.protocolState = "IDLE";
              sendRequestsFromQueue();
            }


          }
        }
      }
      break;
      case "RESPONSE": {
        if (connectionState.protocolState != "WAITING" && !isInLoggedInPartsOfApp) {
          sendDebugMessage("Client received a RESPONSE message, but wasn't waiting for a response");
        } else {
          if (pack.length < 3) {
            sendDebugMessage("Client received a malformed RESPONSE message - this message type should contain at least RESPONSE, REQUESTID, REQUESTTYPE");
          } else {
            if (!pack[1].startsWith("REQUESTID:")) {
              sendDebugMessage("Missing field REQUESTID:number in packet, instead found "+pack[1]);
            } else {
              String requestidString = pack[1].substring("REQUESTID:".length);
              int requestid = int.parse(requestidString, onError: (String source) => -1);
              if (requestid == -1) {
                sendDebugMessage("Client received request where the requestID wasn't an integer ("+requestidString+")");
              } else {
                if (waitingRequests.containsKey(requestid)) {
                  print("successfully identified packet with requestid "+requestidString);
                  String responsetype = pack[2];
                  List<String> fields = [];
                  for (int i = 3; i < pack.length; i++) {
                    fields.add(pack[i]);
                  }
                  waitingRequests[requestid]?.onReply(Response(responsetype, fields));
                  waitingRequests.remove(requestid);
                  connectionState.waitingPackets--;
                  if (connectionState.waitingPackets == 0) {
                    connectionState.protocolState = "IDLE";
                  }
                } else {
                  sendDebugMessage("Client received packet with invalid REQUESTID of "+requestidString);

                }
              }
            }
          }
        }
      }
      break;
      case "NOTIFICATION": {
        if (connectionState.userID == "") {
          sendDebugMessage("Client received a notification, but wasn't logged in");
        } else {
          if (pack.length != 7) {
            sendDebugMessage("Client received a malformed RESPONSE message - this message type should contain exactly seven things: NOTIFICATION, NOTIFICATIONTYPE, NOTIFICATIONID, \"title\", \"body\", TIMESTAMP, and a dot-seperated list of option in strings");
          } else {
            // TODO: deal with case NOTIFICATION
            print("Client received a notification packet "+packet);
          }
        }
      }
      break;
      default: {
        sendDebugMessage("Received unknown packet type '" + pack[0] + "'");
      }
      break;
    }
  }

}

class Encryptor {
  // NEVER CHANGE THIS, OR WE BREAK ALL STORED PASSWORDS
  static String allowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890";

  static int hashStringToInt(String string) {
    int hash  = 7;
    for (int c in string.codeUnits) {
      hash = (hash * 31) + c;
    }
    return hash;
  }

  static String makeStringFromInt(int n) {
    int nLeft = n;
    String string = "";
    while (nLeft > 0) {
      string = string + allowedChars[nLeft % (allowedChars.length)];
      nLeft = nLeft - (nLeft % allowedChars.length);
      nLeft = nLeft ~/ allowedChars.length;
    }
    return string;
  }

  static String hashStringToString(String plaintext) {
    return makeStringFromInt(hashStringToInt(plaintext));
  }

}

class TimeFormatter {
  static toVisualDate(int unixtime) {
    DateTime d = DateTime.fromMillisecondsSinceEpoch(unixtime*1000);
    String s = d.toString();
    print(DateTime.now().toUtc().millisecondsSinceEpoch/1000);
    if (d.difference(DateTime.now()).inDays < 3 && d.day == DateTime.now().day) {
      return s.split(" ")[1].split(":")[0]+":"+s.split(" ")[1].split(":")[1]+" Today";
    } else {
      return s.split(" ")[0];
    }
  }
}

class CurrencyFormatter{
  static toVisualCurrency(int pence) {
    String penceOnly = (pence % 100).toString();
    if (penceOnly.length==1) {
      penceOnly = "0"+penceOnly;
    }
    return "£"+(pence ~/ 100).toString()+"."+penceOnly;
  }
}

class PersistentWidgetState {
  String state = "IDLE";
  late Response response;
  // Possible states: IDLE, WAITING, LOADED, ERROR
  PersistentWidgetState();

}

class RequestWidget extends StatefulWidget {
  const RequestWidget({Key? key,
    required this.waitingWidget,
    required this.errorWidget,
    required this.loadedWidgetGenerator,
    required this.staticRequest,
    required this.stateIdentifier
  }) : super(key : key);

  final Widget waitingWidget;
  final Widget errorWidget;
  final Widget? Function(Response response) loadedWidgetGenerator;
  final StaticRequest staticRequest;
  final String stateIdentifier;

  @override
  State<RequestWidget> createState() => _RequestWidgetState();
}

class _RequestWidgetState extends State<RequestWidget> {
  bool isDisposed = false;

  @override
  void dispose() {
    isDisposed = true;
    super.dispose();
  }

  @override
  void initState() {
    print("Initstate called in _RequestWidgetState with key "+widget.stateIdentifier);
    isDisposed = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    PersistentWidgetState widgetState = PersistentProtocolConnection().stateFromID(widget.stateIdentifier);
    if (widgetState.state == "IDLE") {
      PersistentProtocolConnection().addAndSendRequest(widget.staticRequest.toRequest(
              (Response response) {
            print("Reply function called, widget state set to loaded");
            if (!isDisposed) {
              setState(() {
                widgetState.response = response;
                widgetState.state = "LOADED";
              });
            } else {
              print("actually not, because the widget was already disposed");
            }

          }
      ));
      widgetState.state = "WAITING";
    }

    if (widgetState.state == "WAITING") {
      return widget.waitingWidget;
    } else {
      if (widgetState.state == "LOADED") {
        Widget? generated;
        try {
          generated = widget.loadedWidgetGenerator(widgetState.response);
        } catch (error) {
          print("Error on generating RequestWidget");
          print(error);
          generated = null;
        }
        if (generated != null) {
          return generated;
        }
      }
      return widget.errorWidget;
    }
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String lastFeedbackLabel = "";
  String username = "";
  String password = "";
  bool isSubmitButtonDisabled = false;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();


  void _setFeedbackString(String feedback) {
    setState(() {
      lastFeedbackLabel = feedback;
    });
  }

  void setSubmitButtonDisabled(bool isDisabled) {
    setState(() {
      isSubmitButtonDisabled = isDisabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {return false;},
      child: Scaffold(
          appBar: AppBar(
              automaticallyImplyLeading: false,
              title: const Text("Log in or create an account")
          ),
          body: Center(
              child: Column(
                  children: [
                    Text(lastFeedbackLabel),
                    TextField(
                      decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Username'
                      ),
                      onChanged: (entered) {
                        username = entered;
                        if (entered.contains('"')) {
                          _setFeedbackString("Username cannot contain '\"'");
                        }
                      },
                      controller: _usernameController,
                      onSubmitted: (string) {
                        _passwordController.value = _passwordController.value.copyWith(
                            text: password,
                            selection: TextSelection.collapsed(offset: password.length)
                        );
                      },
                    ),
                    TextField(
                      decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Password'
                      ),
                      onChanged: (entered) {
                        password = entered;
                      },
                      controller: _passwordController,
                      obscureText: true,
                      // DON'T EDIT THIS HERE
                      // EDIT THE SUBMIT BUTTON VERSION AND COPY IT OVER
                      onSubmitted: isSubmitButtonDisabled ? null : (string) {
                        if (username.contains('"')) {
                          _setFeedbackString("Username cannot contain \"");
                          return;
                        }
                        Future.microtask(() => setSubmitButtonDisabled(true));
                        String encryptedPassword = Encryptor.hashStringToString(password);
                        PersistentProtocolConnection().addAndSendRequest(Request("LOGIN", ['USERNAME:"'+username+'"','PASSWORD:"'+encryptedPassword+'"'], (response) {
                          print("got back response with type "+response.type+" and fields "+response.fields.toString());
                          if (response.fields.length < 2) {
                            PersistentProtocolConnection().sendDebugMessage("Received a response to a LOGIN request, but it was missing fields");
                            _setFeedbackString("Server experienced an unknown error");
                          } else {
                            if (response.fields[0]=="SUCCESS" && response.fields[1].startsWith("USERID:")) {
                              PersistentProtocolConnection()..saveToDisk("USERNAME", username)..saveToDisk("ENCRYPTEDPASSWORD",encryptedPassword)
                                ..userID = response.fields[1].substring("USERID:".length)
                                ..connectionState.currentlyLoggedIn = true
                                ..username = username
                                ..password = password
                                ..encryptedPassword = encryptedPassword;
                              //print("literally just set userID to "+PersistentProtocolConnection().userID);
                              Future.microtask(() {
                                Navigator.pop(context);
                              });

                            } else {
                              _setFeedbackString(response.fields[1].substring(1,response.fields[1].length-1));
                            }
                          }
                          Future.microtask(() => setSubmitButtonDisabled(false));
                        }));
                      },
                    ),
                    ElevatedButton(
                      // REMEMBER WHEN EDITING THIS TO COPY IT ONTO THE FORM SUBMIT BUTTON
                      // WE CAN'T DECLARE IT ELSEWHERE BECAUSE OF SOME INTERESTING DYNAMICS ABOUT INITIALIZERS
                        child: Text("Log in"),
                        onPressed: isSubmitButtonDisabled ? null : () {
                          if (username.contains('"')) {
                            _setFeedbackString("Username cannot contain \"");
                            return;
                          }
                          Future.microtask(() => setSubmitButtonDisabled(true));
                          String encryptedPassword = Encryptor.hashStringToString(password);
                          PersistentProtocolConnection().addAndSendRequest(Request("LOGIN", ['USERNAME:"'+username+'"','PASSWORD:"'+encryptedPassword+'"'], (response) {
                            print("got back response with type "+response.type+" and fields "+response.fields.toString());
                            if (response.fields.length < 2) {
                              PersistentProtocolConnection().sendDebugMessage("Received a response to a LOGIN request, but it was missing fields");
                              _setFeedbackString("Server experienced an unknown error");
                            } else {
                              if (response.fields[0]=="SUCCESS" && response.fields[1].startsWith("USERID:")) {
                                PersistentProtocolConnection()..saveToDisk("USERNAME", username)..saveToDisk("ENCRYPTEDPASSWORD",encryptedPassword)
                                  ..userID = response.fields[1].substring("USERID:".length)
                                  ..connectionState.currentlyLoggedIn = true
                                  ..username = username
                                  ..password = password
                                  ..encryptedPassword = encryptedPassword;
                                Future.microtask(() {
                                  Navigator.pop(context);
                                });

                              } else {
                                _setFeedbackString(response.fields[1].substring(1,response.fields[1].length-1));
                              }
                            }
                            Future.microtask(() => setSubmitButtonDisabled(false));
                          }));
                        }
                    ),
                    OutlinedButton(
                        child: Text("Create new account"),
                        onPressed: isSubmitButtonDisabled ? null: () async {
                          Object? o = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CreateAccountPage())
                          );
                          print("got object back from createAccountform");
                          print(o.toString());
                          if (o is String) {
                            _usernameController.value = _usernameController.value.copyWith(
                                text: o,
                                selection: TextSelection.collapsed(offset: o.length)
                            );
                            username = o;
                            if (PersistentProtocolConnection().username == o) {
                              _passwordController.value = _passwordController.value.copyWith(
                                  text: PersistentProtocolConnection().password,
                                  selection: TextSelection.collapsed(offset: PersistentProtocolConnection().password.length)
                              );
                              password = PersistentProtocolConnection().password;
                            }
                          }
                        }
                    )
                  ]
              )
          )
      ),
    );
  }
}

class AddBudgetPage extends StatefulWidget {
  const AddBudgetPage({Key? key, required this.currentBudget, required this.groupID}) : super(key: key);
  final int currentBudget;
  final String groupID;

  @override
  State<AddBudgetPage> createState() => _AddBudgetPageState();
}

class _AddBudgetPageState extends State<AddBudgetPage> {
  String feedback = "";
  String amount = "";
  bool waitingForServer = false;
  bool disposed = false;

  void _setFeedback(String string) {
    setState(() {
      feedback = string;
    });
  }

  void _setWaitingForServer(bool value) {
    setState(() {
      waitingForServer = value;
    });
  }

  @override
  void initState() {
    feedback = "";
    amount = "";
    waitingForServer = false;
    disposed = false;
    super.initState();
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("building widget with waitingForServer = "+waitingForServer.toString());
    if (PersistentProtocolConnection().spontaneousLogOut) {
      Future.microtask(() {
        Navigator.pop(context);
      });
      return Scaffold(
          appBar: AppBar(
              title: Text("Add Budget")
          ),
          body: const Center(
              child: Text("Hang on...")
          )
      );
    }
    void submitForm() {
      print("submit form called");
      List<String> splitAmount = amount.split(".");
      int amountPoundsOnly;
      int amountPenceOnly;
      if (splitAmount.length == 1) {
        if (int.tryParse(splitAmount[0]) != null) {
          if (int.parse(splitAmount[0]) < 100 && int.parse(splitAmount[0]) > 0) {
            amountPoundsOnly = int.parse(splitAmount[0]);
            amountPenceOnly = 0;
            print("adding budget (pounds only)");
            Future.microtask(() {
              _setFeedback("Adding budget...");
              _setWaitingForServer(true);
            });
            print("added budget");
            PersistentProtocolConnection().addAndSendRequest(Request(
                "ADDBUDGET",
                ["AMOUNT:"+((amountPoundsOnly*100)+amountPenceOnly).toString(),"GROUPID:"+widget.groupID],
                    (response) {
                  if (!disposed) {
                    if (response.fields.length == 1 && response.fields[0] == "SUCCESS") {
                      Navigator.pop(context);
                    } else {
                      if (response.fields.length > 1) {
                        _setFeedback(response.fields[1].substring(1,response.fields[1].length-1));
                      } else {
                        _setFeedback("This failed for an unknown reason - try reloading this page");
                      }
                      _setWaitingForServer(false);
                    }
                  }
                }
            ));
          } else {
            _setFeedback("Invalid amount £"+int.parse(splitAmount[0]).toString()+" entered");
          }
        } else {
          _setFeedback("Invalid amount '£"+splitAmount[0]+"' entered");
        }
      } else if (splitAmount.length == 2) {
        if (splitAmount[1].length == 1) {
          splitAmount[1] += "0";
        }
        if (int.tryParse(splitAmount[0]) != null && int.tryParse(splitAmount[1]) != null) {
          amountPoundsOnly = int.parse(splitAmount[0]);
          amountPenceOnly = int.parse(splitAmount[1]);
          if (amountPoundsOnly >= 0 && amountPenceOnly >= 0 && (amountPoundsOnly > 0 || amountPenceOnly > 0) && amountPenceOnly < 100) {
            print("adding budget (pounds and pence)");
            Future.microtask(() {
              _setFeedback("Adding budget...");
              _setWaitingForServer(true);
            });
            PersistentProtocolConnection().addAndSendRequest(Request(
                "ADDBUDGET",
                ["AMOUNT:"+((amountPoundsOnly*100)+amountPenceOnly).toString(),"GROUPID:"+widget.groupID],
                    (response) {
                  if (!disposed) {
                    if (response.fields.length == 1 && response.fields[0] == "SUCCESS") {
                      Navigator.pop(context);
                    } else {
                      if (response.fields.length > 1) {
                        _setFeedback(response.fields[1].substring(1,response.fields[1].length-1));
                      } else {
                        _setFeedback("This failed for an unknown reason - try reloading this page");
                      }
                    }
                    _setWaitingForServer(false);
                  }
                }
            ));
          } else {
            _setFeedback("Invalid '£"+amountPoundsOnly.toString()+"."+amountPenceOnly.toString()+" entered");
          }
        } else {
          _setFeedback("Invalid amount '£"+splitAmount[0]+"."+splitAmount[1]+"' entered");
        }
      } else {
        _setFeedback("Invalid amount entered - could not parse");
      }
    };
    return Scaffold(
        appBar: AppBar(
            title: Text("Add Budget")
        ),
        body: Center(
            child: Column(
              children: [
                Text(feedback),
                Row(
                  children: [
                    const Text("£"),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Enter amount'
                        ),
                        onChanged: (entered) {
                          amount = entered;
                        },
                        onSubmitted: waitingForServer ? null : (dummy) => submitForm(),
                      ),
                    ),
                    ElevatedButton(
                      child: const Text("Add"),
                      onPressed: waitingForServer ? null : submitForm,
                    )
                  ],
                )
              ],
            )
        )
    );
  }
}

class InviteUserPage extends StatefulWidget {
  const InviteUserPage({Key? key, required this.groupName, required this.groupID}) : super(key: key);
  final String groupName;
  final String groupID;

  @override
  State<InviteUserPage> createState() => _InviteUserPageState();
}

class _InviteUserPageState extends State<InviteUserPage> {
  bool isDisposed = false;
  bool waitingForServer = false;
  String feedback = "";
  String enteredUsername = "";

  @override
  void initState() {
    isDisposed = false;
    feedback = "";
    enteredUsername = "";
    waitingForServer = false;
    super.initState();
  }

  void _setFeedback(String string) {
    setState(() {
      feedback = string;
    });
  }

  void _setWaitingForServer(bool value) {
    setState(() {
      waitingForServer = value;
    });
  }

  @override
  void dispose() {
    isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void submitForm() {
      String sentName = enteredUsername;
      if (sentName.contains('"')) {
        _setFeedback("User names cannot contain \"");
        return;
      }
      _setWaitingForServer(true);
      PersistentProtocolConnection().addAndSendRequest(Request(
          "GETUSERBYNAME",
          ['"'+sentName+'"'],
              (response) {
            if (!isDisposed) {
              if (response.fields.length == 3 && response.fields[0] == "SUCCESS") {
                String userID = response.fields[2].substring("USERID:".length);
                PersistentProtocolConnection().addAndSendRequest(Request(
                    "INVITEUSERTOGROUP",
                    ["USERID:"+userID, "GROUPID:"+widget.groupID],
                        (response) {
                      if (!isDisposed) {
                        if (response.fields.length == 1 && response.fields[0] == "SUCCESS") {
                          _setFeedback("Success!");
                          Navigator.pop(context);
                        } else if (response.fields.length == 2 && response.fields[0] == "FAILURE" && response.fields[1].length > 2) {
                          _setFeedback(response.fields[1].substring(1,response.fields[1].length-1));
                        } else {
                          PersistentProtocolConnection().sendDebugMessage("Server sent wrongly-formatted RESPONSE to a GETUSERINFO packet");
                          _setFeedback("Server experienced an unknown error");
                        }
                      }
                      _setWaitingForServer(false);
                    }
                ));
              } else {
                _setFeedback("Cannot find user '"+sentName+"'");
                _setWaitingForServer(false);
              }
            }
          }
      ));
    }
    if (PersistentProtocolConnection().spontaneousLogOut) {
      Future.microtask(() {
        Navigator.pop(context);
      });
      return Scaffold(
          appBar: AppBar(
              title: Text("Invite user to "+widget.groupName)
          ),
          body: const Center(
              child: Text("Hang on...")
          )
      );
    }
    return Scaffold(
        appBar: AppBar(
            title: Text("Invite user to "+widget.groupName)
        ),
        body: Center(
            child: Column(
                children: [
                  Text(feedback),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Enter username'
                          ),
                          onChanged: (entered) {
                            if (!waitingForServer) {
                              enteredUsername = entered;
                              PersistentProtocolConnection().addAndSendRequest(Request(
                                  "GETUSERBYNAME",
                                  ['"'+entered+'"'],
                                      (response) {
                                    if (enteredUsername == entered) {
                                      if (response.fields.length > 0) {
                                        if (response.fields[0] != "SUCCESS") {
                                          _setFeedback("Cannot find user '"+enteredUsername+"'");
                                        } else {
                                          _setFeedback("");
                                        }
                                      } else {
                                        PersistentProtocolConnection().sendDebugMessage("Client received GETUSERBYNAME packet with no fields");
                                      }
                                    } else {
                                      print("received reply, but username out of date");
                                    }
                                  }
                              ));
                            }
                          },
                          onSubmitted: waitingForServer ? null : (dummy) => submitForm(),
                        ),
                      ),
                      ElevatedButton(
                        child: const Text("Invite"),
                        onPressed: waitingForServer ? null : submitForm,
                      )
                    ],
                  )
                ]
            )
        )
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool isDisposed = false;
  bool waitingForServer = false;
  String usernameFeedback = "";
  String passwordFeedback = "";
  String username = "";
  String oldPassword = "";
  String password = "";
  String confirmPassword = "";

  void _setUsernameFeedback(String string) {
    setState(() {
      usernameFeedback = string;
    });
  }

  void _setPasswordFeedback(String string) {
    setState(() {
      passwordFeedback = string;
    });
  }

  void _setServerWaiting(bool value) {
    setState(() {
      waitingForServer = value;
    });
  }

  @override
  void initState() {
    isDisposed = false;
    waitingForServer = false;
    usernameFeedback = "";
    passwordFeedback = "";
    username = "";
    oldPassword = "";
    password = "";
    confirmPassword = "";
    super.initState();
  }

  @override
  void dispose() {
    isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void submitChangeUsername() {
      if (username.contains('"')) {
        _setUsernameFeedback("Username cannot contain \"");
        return;
      }
      _setServerWaiting(true);
      _setUsernameFeedback("Changing name...");
      PersistentProtocolConnection().addAndSendRequest(Request(
          "SETPERSONALSETTING",
          ["NAME:\""+username+'"'],
              (response) {
            if (response.fields.length == 2 && response.fields[0] == "SUCCESS" && response.fields[1].startsWith("NAME:\"") && response.fields[1].length > 'NAME:"""'.length) {
              String newName = response.fields[1].substring("NAME:\"".length, response.fields[1].length-1);
              _setUsernameFeedback("Username changed to \""+newName+'"');
              PersistentProtocolConnection()..username = newName
                ..saveToDisk("USERNAME", newName);
              _setServerWaiting(false);
            } else if (response.fields.length == 2 && response.fields[0] == "FAILURE" && response.fields[1].length > 2) {
              _setUsernameFeedback(response.fields[1].substring(1,response.fields[1].length-1));
              _setServerWaiting(false);
            } else {
              _setUsernameFeedback("Server failed to give a valid response - try looking at a group you're in to see if your name has changed");
              PersistentProtocolConnection().sendDebugMessage("Client received response to SETPERSONALSETTING request that didn't match the SUCCESS or FAILURE formats");
              _setServerWaiting(false);
            }
          }
      ));
    }
    void sendChangePassword() {
      _setServerWaiting(true);
      _setPasswordFeedback("Changing password...");
      PersistentProtocolConnection().addAndSendRequest(Request(
          "SETPERSONALSETTING",
          ["PASSWORD:\""+Encryptor.hashStringToString(password)+'"'],
              (response) {
            if (response.fields.length == 2 && response.fields[0] == "SUCCESS" && response.fields[1].startsWith("PASSWORD:\"") && response.fields[1].length > 'PASSWORD:"""'.length) {
              String newEncryptedPassword = response.fields[1].substring("PASSWORD:\"".length, response.fields[1].length-1);
              _setPasswordFeedback("Password successfully changed");
              PersistentProtocolConnection()..password = password
                ..encryptedPassword = newEncryptedPassword
                ..saveToDisk("ENCRYPTEDPASSWORD", newEncryptedPassword);
              if (Encryptor.hashStringToString(password) != newEncryptedPassword) {
                _setPasswordFeedback("Response from server indicates password might not have been set correctly - please contact available support for more information about this");
              }
              _setServerWaiting(false);
            } else if (response.fields.length == 2 && response.fields[0] == "FAILURE" && response.fields[1].length > 2) {
              _setPasswordFeedback(response.fields[1].substring(1,response.fields[1].length-1));
              _setServerWaiting(false);
            } else {
              _setPasswordFeedback("Server failed to give a valid response - next time you need to log in, try your old and new passwords to see which one is currently correct");
              PersistentProtocolConnection().sendDebugMessage("Client received response to SETPERSONALSETTING request that didn't match the SUCCESS or FAILURE formats");
              _setServerWaiting(false);
            }
          }
      ));
    }
    void submitPasswordChanged() {
      if (password != confirmPassword) {
        _setPasswordFeedback("The new password does not match the confirmation password");
      } else {
        if (oldPassword == PersistentProtocolConnection().password) {
          sendChangePassword();
        } else {
          PersistentProtocolConnection().getFromDisk("ENCRYPTEDPASSWORD").then((encryptedPassword) {
            if (encryptedPassword != null) {
              if (encryptedPassword == Encryptor.hashStringToString(oldPassword)) {
                sendChangePassword();
                return;
              }
            }
            _setPasswordFeedback("We couldn't match your old password - make sure it's entered correctly");
          });
        }
      }
    }

    if (PersistentProtocolConnection().spontaneousLogOut) {
      Future.microtask(() {
        Navigator.pop(context);
      });
      return Scaffold(
          appBar: AppBar(
              title: Text("Settings")
          ),
          body: const Center(
              child: Text("Hang on...")
          )
      );
    }
    return Scaffold(
        appBar: AppBar(
            title: Text("Settings")
        ),
        body:
        ListView(
            shrinkWrap: true,
            children: [
              SizedBox(height:50),
              Text("Change username:"),
              Row(
                  children: [
                    Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Set username'
                          ),
                          onChanged: (entered) {
                            username = entered;
                            if (username.contains('"')) {
                              _setUsernameFeedback("Username cannot contain \"");
                            }
                          },
                          onSubmitted: waitingForServer ? null : (dummy) => submitChangeUsername(),
                        )
                    ),
                    ElevatedButton(
                        child: Text("Set"),
                        onPressed: waitingForServer ? null : submitChangeUsername
                    )
                  ]
              ),
              Text(usernameFeedback),
              SizedBox(height:50),
              Text("Change password:"),
              TextField(
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Current password'
                ),
                onChanged: (entered) {
                  oldPassword = entered;
                },
                obscureText: true,
              ),
              Text(passwordFeedback),
              TextField(
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'New password'
                ),
                onChanged: (entered) {
                  password = entered;
                },
                obscureText: true,
              ),
              TextField(
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Confirm new password'
                  ),
                  onChanged: (entered) {
                    confirmPassword = entered;
                  },
                  obscureText: true,
                  onSubmitted: waitingForServer ? null : (dummy) => submitPasswordChanged()
              ),
              ElevatedButton(
                  child: Text("Change"),
                  onPressed: waitingForServer ? null : submitPasswordChanged
              ),
              SizedBox(height:50),
              OutlinedButton(
                  child:Text("Log out"),
                  onPressed: waitingForServer ? null : () {
                    _setServerWaiting(true);
                    PersistentProtocolConnection().addAndSendRequest(Request(
                        "LOGOUT",
                        [],
                            (response) {
                          if (response.fields.length > 1) {
                            PersistentProtocolConnection().sendDebugMessage("Somehow the logout failed with message "+response.fields[1]);
                            _setPasswordFeedback("Somehow the logout failed - try closing and reopening the app");
                            _setServerWaiting(false);
                          } else {
                            PersistentProtocolConnection()..connectionState.currentlyLoggedIn = false
                              ..spontaneousLogOut = true;
                            Navigator.pop(context);
                          }
                        }
                    ));
                  }
              )
            ]
        )

    );
  }
}

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({Key? key}) : super(key: key);

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  String feedback = "";
  String groupName = "";
  bool isDisposed = false;
  bool waitingForServer = false;

  @override
  void initState() {
    feedback = "";
    isDisposed = false;
    waitingForServer = false;
    super.initState();
  }

  @override
  void dispose() {
    isDisposed = true;
    super.dispose();
  }

  void _setWaitingForServer(bool value) {
    setState(() {
      waitingForServer = value;
    });
  }

  void _setFeedback(String string) {
    setState(() {
      feedback = string;
    });
  }


  @override
  Widget build(BuildContext context) {
    if (PersistentProtocolConnection().spontaneousLogOut) {
      Future.microtask(() {
        Navigator.pop(context);
      });
      return Scaffold(
          appBar: AppBar(
              title: const Text("Create Household")
          ),
          body: const Center(
              child: Text("Hang on...")
          )
      );
    }
    void submitForm(String gname) {
      if (gname.contains('"')) {
        _setFeedback("Household name cannot contain \"");
        return;
      }
      _setWaitingForServer(true);
      _setFeedback("Creating household...");
      PersistentProtocolConnection().addAndSendRequest(Request(
          "CREATEGROUP",
          ['"'+gname+'"'],
              (response) {
            if (response.fields.length > 1 && response.fields[0] == "SUCCESS" && response.fields[1].startsWith("GROUPID:")) {
              _setFeedback("Success!");
              Navigator.pop(context, GroupNameAndId(gname, response.fields[1].substring("GROUPID:".length)));
            } else if (response.fields.length > 1 && response.fields[0] == "FAILURE" && response.fields[1].length > 1) {
              _setFeedback(response.fields[1].substring(1,response.fields[1].length-1));
            } else {
              _setFeedback("Server failed to reply - check your groups to see if the group creation succeeded");
              PersistentProtocolConnection().sendDebugMessage("Client received a response to a CREATEGROUP request that it couldn't match with the SUCCESS or FAILURE format");
            }
            _setWaitingForServer(false);
          }
      ));
    }
    return Scaffold(
        appBar: AppBar(
            title: const Text("Create Household")
        ),
        body: Center(
            child: Column(
                children: [
                  Text(feedback),
                  Row(
                      children: [
                        Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'Enter username'
                              ),
                              onChanged: (entered) {
                                groupName = entered;
                              },
                              onSubmitted: waitingForServer ? null : (string) => submitForm(string),
                            )
                        ),
                        ElevatedButton(
                            child: const Text("Create"),
                            onPressed: waitingForServer ? null : () => submitForm(groupName)
                        )
                      ]
                  )
                ]
            )
        )
    );
  }
}

class GroupPage extends StatefulWidget {
  const GroupPage({Key? key, required this.groupName, required this.groupID}) : super(key: key);
  final String groupName;
  final String groupID;

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage>{
  int currentBudget = -1;
  bool pageLoaded = false;
  bool needsRefresh = false;


  void forceRebuild() {
    setState(() {
      PersistentProtocolConnection().wipeStateWithID("GROUPPAGE");
    });
  }

  @override
  @mustCallSuper
  void initState() {
    print("initstate called in _GroupPageState");
    forceRebuild();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (PersistentProtocolConnection().spontaneousLogOut) {
      Future.microtask(() {
        Navigator.pop(context);
      });
      return Scaffold(
          appBar: AppBar(
              title: Text(widget.groupName)
          ),
          body: const Center(
              child: Text("Hang on...")
          )
      );
    }
    return WillPopScope(
        onWillPop: () async {
          forceRebuild();
          return true;
        },
        child: Scaffold(
          appBar: AppBar(
              title: Row(
                  children: [
                    Text(widget.groupName),
                    Spacer(),
                    /*
              ElevatedButton(
                child: Text("Notifications"),
                onPressed:() async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => NotificationsPage())
                  );
                  forceRebuild();
                },
              )
              */
                  ]
              )
          ),
          body: Center(
              child: RequestWidget(
                waitingWidget: Text("Loading Household Info..."),
                errorWidget: Text("Failed to load info for this household. Maybe try refreshing?"),
                loadedWidgetGenerator: (Response response) {
                  if (response.fields.length >= 3 && response.fields[0] == "SUCCESS") {
                    print("response fields 2 = "+response.fields[2]);
                    print("own userID = "+PersistentProtocolConnection().userID);
                    List<Widget> groupItems = [];
                    int positionCounter = 3;

                    int maxPenniesPositionCounter = 3;
                    int maxPennies = 0;
                    while (maxPenniesPositionCounter < response.fields.length - 2) {
                      int? individualPennies = int.tryParse(response.fields[maxPenniesPositionCounter+2].substring("BUDGET:".length));
                      if (individualPennies != null ) {
                        if (individualPennies > maxPennies) {
                          maxPennies = individualPennies;
                        }
                      }
                      maxPenniesPositionCounter = maxPenniesPositionCounter + 3;
                    }


                    while (positionCounter < response.fields.length - 2) {
                      String memberID = response.fields[positionCounter].substring("MEMBER:".length);
                      String memberName = response.fields[positionCounter+1].substring("NAME:\"".length,response.fields[positionCounter+1].length-1);
                      int? budget = int.tryParse(response.fields[positionCounter+2].substring("BUDGET:".length));
                      if (budget == null) {
                        return null;
                      }
                      groupItems.add(InkWell(
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: (maxPennies == 0) ? Text(memberName+" ("+CurrencyFormatter.toVisualCurrency(budget)+")") : Stack(
                              children: [
                                Container(
                                    width:(MediaQuery.of(context).size.width-40)*(budget/maxPennies),
                                    height:24,
                                    color: Colors.green.withOpacity(0.7)
                                ),
                                Text(memberName+" ("+CurrencyFormatter.toVisualCurrency(budget)+")"),
                              ],
                            )
                        ),
                        onLongPress: (PersistentProtocolConnection().userID != response.fields[2].substring("ADMIN:".length)) ? () => {} : () async {
                          bool madeChange = false;
                          await showDialog<String>(
                              context: context,
                              builder: (BuildContext context2) => AlertDialog(
                                  title: Text("Admin actions:"),
                                  content: Text("You can remove "+memberName+", or make them an admin"),
                                  actions: <Widget>[
                                    TextButton(
                                        onPressed: () => Navigator.pop(context2),
                                        child: const Text("Cancel")
                                    ),
                                    TextButton(
                                        onPressed: () {
                                          showDialog<String>(
                                            context: context2,
                                            builder: (BuildContext context3) => AlertDialog(
                                                title: Text("Make "+memberName+" Admin"),
                                                content: Text("Are you sure you want to make "+memberName+" the admin of this household? You will no longer be the admin."),
                                                actions: <Widget>[
                                                  TextButton(
                                                      onPressed: () {
                                                        Navigator.pop(context3);
                                                      },
                                                      child: Text("Cancel")
                                                  ),
                                                  TextButton(
                                                      onPressed: () {
                                                        PersistentProtocolConnection().addAndSendRequest(Request(
                                                            "SETGROUPSETTING",
                                                            ["GROUPID:"+widget.groupID,"ADMIN:"+memberID],
                                                                (response) async {

                                                              if (response.fields.length > 1 && response.fields[0]=="SUCCESS") {
                                                                print("got make admin response: success");
                                                                madeChange = true;
                                                                await showDialog<String>(
                                                                    context: context3,
                                                                    builder: (BuildContext context4) => AlertDialog(
                                                                        title: Text("Success!"),
                                                                        content: Text(memberName+" is now the admin of this group"),
                                                                        actions: <Widget>[
                                                                          TextButton(
                                                                              onPressed: () => Navigator.pop(context4,"SUCCESS"),
                                                                              child: Text("OK")
                                                                          )
                                                                        ]
                                                                    )
                                                                );
                                                                Navigator.pop(context3,"SUCCESS");
                                                                Navigator.pop(context2);
                                                              } else {
                                                                print("got make admin response: failure");
                                                                await showDialog<String>(
                                                                    context: context3,
                                                                    builder: (BuildContext context4) => AlertDialog(
                                                                        title: Text("Failed to make admin"),
                                                                        content: Text("Failure message: "+response.fields[1]),
                                                                        actions: <Widget>[
                                                                          TextButton(
                                                                              onPressed: () => Navigator.pop(context4),
                                                                              child: Text("OK")
                                                                          )
                                                                        ]
                                                                    )
                                                                );
                                                                print("showed dialog");
                                                                Navigator.pop(context3);
                                                              }
                                                            }
                                                        ));
                                                      },
                                                      child: Text("Confirm")
                                                  )
                                                ]
                                            ),
                                          );
                                        },
                                        child: const Text("Make Admin")
                                    ),
                                    TextButton(
                                        onPressed: () {
                                          showDialog<String>(
                                            context: context2,
                                            builder: (BuildContext context3) => AlertDialog(
                                                title: Text("Remove "+memberName),
                                                content: Text("Are you sure you want to remove "+memberName+" from this household?"),
                                                actions: <Widget>[
                                                  TextButton(
                                                      onPressed: () {
                                                        Navigator.pop(context3);
                                                      },
                                                      child: Text("Cancel")
                                                  ),
                                                  TextButton(
                                                      onPressed: () {
                                                        PersistentProtocolConnection().addAndSendRequest(Request(
                                                            "REMOVEUSER",
                                                            ["USERID:"+memberID,"GROUPID:"+widget.groupID],
                                                                (response) async {
                                                              if (response.fields.length == 1 && response.fields[0]=="SUCCESS") {
                                                                madeChange = true;
                                                                await showDialog<String>(
                                                                    context: context3,
                                                                    builder: (BuildContext context4) => AlertDialog(
                                                                        title: Text("User removed"),
                                                                        content: Text(memberName+" has been removed from this household"),
                                                                        actions: <Widget>[
                                                                          TextButton(
                                                                              onPressed: () => Navigator.pop(context4),
                                                                              child: Text("OK")
                                                                          )
                                                                        ]
                                                                    )
                                                                );
                                                                Navigator.pop(context3);
                                                                Navigator.pop(context2);
                                                              } else {
                                                                String failure;
                                                                if (response.fields.length > 1) {
                                                                  failure = response.fields[1];
                                                                } else {
                                                                  failure = "No message given";
                                                                }
                                                                await showDialog<String>(
                                                                    context: context3,
                                                                    builder: (BuildContext context4) => AlertDialog(
                                                                        title: Text("Failed to remove user"),
                                                                        content: Text("Failure message: "+failure),
                                                                        actions: <Widget>[
                                                                          TextButton(
                                                                              onPressed: () => Navigator.pop(context4),
                                                                              child: Text("OK")
                                                                          )
                                                                        ]
                                                                    )
                                                                );
                                                                Navigator.pop(context3);
                                                              }
                                                            }
                                                        ));
                                                      },
                                                      child: Text("Remove")
                                                  )
                                                ]
                                            ),
                                          );
                                        },
                                        child: const Text("Remove from group")
                                    ),
                                  ]
                              )
                          );
                          if (madeChange) {
                            forceRebuild();
                          }
                        },
                      ));
                      positionCounter = positionCounter + 3;
                      groupItems.add(Divider());
                    }
                    groupItems.add(OutlinedButton(
                        onPressed: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => InviteUserPage(groupName: widget.groupName, groupID: widget.groupID))
                          );
                          forceRebuild();
                        },
                        child: Text("+ Invite User")
                    ));
                    return ListView(
                        children: groupItems
                    );
                  }
                },
                staticRequest: StaticRequest("GETGROUPINFO",["GROUPID:"+widget.groupID]),
                stateIdentifier: "GROUPPAGE",
              )
          ),
          bottomNavigationBar: BottomAppBar(
              child: Container(
                  height: 50,
                  color: Theme.of(context).colorScheme.primary,
                  child: Row(
                      children: [
                        ElevatedButton(
                            child: Text("Enter transaction"),
                            onPressed: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => EnterTransactionPage(groupID: widget.groupID))
                              );
                              forceRebuild();
                            }
                        ),
                        Spacer(),
                        ElevatedButton(
                            child: Text("Add to budget"),
                            onPressed: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => AddBudgetPage(currentBudget: -1, groupID: widget.groupID))
                              );
                              forceRebuild();
                            }
                        ),
                      ]
                  )
              )
          ),
        )
    );
  }
}

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({Key? key}) : super(key: key);

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  String lastFeedbackLabel = "";
  String username = "";
  String password = "";
  String confirmPassword = "";
  bool isFormDisabled = false;

  void _setFeedbackString(String feedback) {
    setState(() {
      lastFeedbackLabel = feedback;
    });
  }

  void setFormDisabled(bool isDisabled) {
    setState(() {
      isFormDisabled = isDisabled;
    });
  }

  @override
  Widget build(BuildContext buildContext) {
    return Scaffold(
        appBar: AppBar(
            title: const Text("Create Account")
        ),
        body: Center(
            child: Column(
              children: [
                Text(lastFeedbackLabel),
                TextField(
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Username'
                  ),
                  readOnly: isFormDisabled,
                  onChanged: (entered) {
                    username = entered;
                    if (username.contains('"')) {
                      _setFeedbackString("Username cannot contain \"");
                    }
                  },
                ),
                TextField(
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Password'
                  ),
                  readOnly: isFormDisabled,
                  onChanged: (entered) {
                    password = entered;
                  },
                  obscureText: true,
                ),
                TextField(
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Confirm Password'
                  ),
                  readOnly: isFormDisabled,
                  onChanged: (entered) {
                    confirmPassword = entered;
                  },
                  obscureText: true,
                ),
                ElevatedButton(
                    child: Text("Submit"),
                    onPressed: isFormDisabled ? null : () {
                      if (username.contains('"')) {
                        _setFeedbackString("Username cannot contain \"");
                        return;
                      }
                      if (password != confirmPassword) {
                        Future.microtask(() => _setFeedbackString("The password entered doesn't match the confirmation password"));
                      } else {
                        Future.microtask(() => setFormDisabled(true));
                        String encryptedPassword = Encryptor.hashStringToString(password);
                        PersistentProtocolConnection().addAndSendRequest(Request("CREATEUSERACCOUNT", ['"'+username+'"','"'+encryptedPassword+'"'], (response) {
                          if (response.fields.length >= 2 && response.fields[0] == "SUCCESS" && response.fields[1].startsWith("USERID:")) {
                            PersistentProtocolConnection()..saveToDisk("USERNAME", username)
                              ..saveToDisk("ENCRYPTEDPASSWORD", password)
                              ..username = username
                              ..encryptedPassword = encryptedPassword
                              ..password = password;
                            Future.microtask(() {
                              setFormDisabled(false);
                              //if we created an account, send back the username
                              Navigator.pop(context, username);
                            });
                          } else if (response.fields.length == 2 && response.fields[0] == "FAILURE" && response.fields[1].startsWith('"') && response.fields[1].endsWith('"')) {
                            Future.microtask(() {
                              _setFeedbackString(response.fields[1].substring(1,response.fields[1].length-1));
                              setFormDisabled(false);
                            });
                          } else {
                            PersistentProtocolConnection().sendDebugMessage("Received FAILURE message for CREATEACCOUNT, but it was weirdly formatted");
                            _setFeedbackString("Account create faied: server encountered an unknown error");
                            setFormDisabled(false);
                          }
                        }));
                      }
                    }
                )
              ],
            )
        )
    );
  }
}

class AllGroupsPage extends StatefulWidget {
  const AllGroupsPage({Key? key}) : super(key: key);

  @override
  State<AllGroupsPage> createState() => _AllGroupsPageState();
}

class _AllGroupsPageState extends State<AllGroupsPage> {

  void forceRebuild() {
    setState(() {
      PersistentProtocolConnection().wipeStateWithID("ALLGROUPSLIST");
    });
  }

  @override
  void initState() {
    forceRebuild();
    super.initState();
  }

  @override
  Widget build(BuildContext buildContext) {
    if (PersistentProtocolConnection().spontaneousLogOut) {
      Future.microtask(() {
        Navigator.pop(context);
      });
      return Scaffold(
          appBar: AppBar(
              title: const Text("Households")
          ),
          body: const Center(
              child: Text("Hang on...")
          )
      );
    }
    return WillPopScope(
      onWillPop: () async {return false;},
      child: Scaffold(
          appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Row(
                  children: [
                    Text("Households"),
                    Spacer(),
                    ElevatedButton(
                      child: Text("Notifications"),
                      onPressed:() async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => NotificationsPage())
                        );
                        forceRebuild();
                      },
                    )
                  ]
              )
          ),
          body: Center(
              child: RequestWidget(
                waitingWidget: Text("Loading households..."),
                errorWidget: Text("Failed to load households"),
                loadedWidgetGenerator: (response) {
                  if (response.fields.length < 3 || response.fields[0] != "SUCCESS") {
                    return null;
                  }
                  List<Widget> groupItems = [];
                  int positionCounter = 3;
                  while (positionCounter < response.fields.length-1) {
                    String groupName = response.fields[positionCounter+1].substring(1,response.fields[positionCounter+1].length-1);
                    String groupID = response.fields[positionCounter];
                    groupItems.add(InkWell(
                      child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(groupName)
                      ),
                      onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => GroupPage(groupName: groupName,groupID: groupID))
                        );
                        forceRebuild();
                      },
                      onLongPress: () => print("inkwell long pressed!"),
                    ));
                    positionCounter = positionCounter + 2;
                    groupItems.add(Divider());
                  }
                  groupItems.add(OutlinedButton(
                      onPressed: () async {
                        Object? o = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CreateGroupPage())
                        );
                        if (o is GroupNameAndId) {
                          String gname = o.groupName;
                          String gID = o.groupID;
                          await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) =>  GroupPage(groupName: gname, groupID: gID))
                          );
                        }
                        forceRebuild();
                      },
                      child: Text("+ Create Household")
                  ));
                  return ListView(
                    children: groupItems,
                  );
                },
                staticRequest: StaticRequest("GETSTATUS",[]),
                stateIdentifier: "ALLGROUPSLIST",
              )
          ),
          bottomNavigationBar: BottomAppBar(
              child: Container(
                  height: 50,
                  color: Theme.of(context).colorScheme.primary,
                  child: Center(
                    child: Container(
                      width:150,
                      child: ElevatedButton(
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children:const [
                                Text("Settings"),
                                Icon(
                                    Icons.settings
                                )
                              ]
                          ),
                          onPressed: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const SettingsPage())
                            );
                            forceRebuild();
                          }
                      ),
                    ),
                  )
              )
          )
      ),
    );
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool waitingForServer = false;
  bool isDisposed = false;

  void _setWaitingForServer(bool value) {
    setState(() {
      waitingForServer = value;
    });
  }

  @override
  void initState() {
    isDisposed = false;
    waitingForServer = false;
    PersistentProtocolConnection().wipeStateWithID("NOTIFICATIONSPAGE");
    super.initState();
  }

  @override
  void dispose() {
    isDisposed = true;
    super.dispose();
  }

  void forceRebuild() {
    setState(() {
      PersistentProtocolConnection().wipeStateWithID("NOTIFICATIONSPAGE");
    });
  }

  @override
  Widget build(BuildContext context) {
    if (PersistentProtocolConnection().spontaneousLogOut) {
      Future.microtask(() {
        Navigator.pop(context);
      });
      return Scaffold(
          appBar: AppBar(
              title: const Text("Notifications")
          ),
          body: Center(
              child: ListView(children: const [SizedBox(height:90),Center(child:Text("Hang on...",style: TextStyle(color:Color(0xffffffff))))])
          )
      );
    }
    Widget createNotificationWidget(String notificationType, String notificationID, String title, String body, String timestamp, List<String> displayOptions) {
      List<Widget> buttons = [];
      for (String option in displayOptions) {
        if (option != "dismiss" && !option.startsWith("hidden:")) {
          buttons.add(OutlinedButton(
              child: Text(option.substring(0,1).toUpperCase()+option.substring(1,option.length)),
              onPressed: waitingForServer ? null : () {
                _setWaitingForServer(true);
                PersistentProtocolConnection().addAndSendRequest(Request(
                    "NOTIFICATIONRESPONSE",
                    ["NOTIFICATIONID:"+notificationID,"RESPONSE:\""+option+'"'],
                        (response) {
                      _setWaitingForServer(false);
                      if (response.fields.length > 1) {
                        print("It looks like notificationresponse failed for some reason - here's the reason:");
                        print(response.fields[1]);
                      }
                      forceRebuild();
                    }
                ));
              }
          ));
        }
      }
      return Padding(
          padding: EdgeInsets.all(10),
          child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(20)),
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    Container(
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Row(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                        children: [
                                          Text(title+" "),
                                          Text(timestamp, style: const TextStyle(color:Colors.grey)),
                                        ]
                                    )
                                ),
                              ),
                              SizedBox(width: 10),
                              IconButton(
                                  iconSize: 20,
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                  onPressed: waitingForServer ? null : () {
                                    _setWaitingForServer(true);
                                    PersistentProtocolConnection().addAndSendRequest(Request(
                                        "NOTIFICATIONRESPONSE",
                                        ["NOTIFICATIONID:"+notificationID,"RESPONSE:\"dismiss\""],
                                            (response) {
                                          _setWaitingForServer(false);
                                          if (response.fields.length > 1) {
                                            print("It looks like notificationresponse failed for some reason - here's the reason:");
                                            print(response.fields[1]);
                                          }
                                          if (!isDisposed) {
                                            forceRebuild();
                                          }
                                        }
                                    ));
                                  },
                                  icon: Icon(
                                    Icons.close_rounded,
                                  )
                              )
                            ],
                          ),
                        )
                    ),
                    Container(
                      color: Color(0x0f000000),
                      child: Padding(
                          padding: EdgeInsets.all(10),

                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(body.split("Â£").join("£")),
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: buttons
                                )
                              ]
                          )
                      ),
                    )
                  ],
                ),
              )
          )
      );
    }
    return Scaffold(
        appBar: AppBar(
            title: const Text("Notifications")
        ),
        body: Center(
            child: Container(
              color: Colors.lightBlue,
              child: RequestWidget(
                waitingWidget: ListView(children:const [SizedBox(height:90),Center(child:Text("Loading notifications...",style: TextStyle(color:Color(0xffffffff))))]),
                errorWidget: ListView(children:const [SizedBox(height:90),Center(child:Text("Failed to load notifications",style: TextStyle(color:Color(0xffffffff))))]),
                loadedWidgetGenerator: (response) {
                  if (response.fields.length > 1 && response.fields[0] == "SUCCESS") {
                    if (response.fields.length == 2) {
                      return ListView(children:const [SizedBox(height:90),Center(child:Text("You have no notifications",style: TextStyle(color:Color(0xffffffff))))]);
                    }
                    List<Widget> notifications = [];
                    int positionCounter = 1;
                    while (positionCounter + 5 < response.fields.length) {
                      print("looking at notification index");
                      try {
                        String notificationType = response.fields[positionCounter];
                        String notificationID = response.fields[positionCounter+1].substring("NOTIFICATIONID:".length);
                        String title = response.fields[positionCounter+2].substring(1, response.fields[positionCounter+2].length-1);
                        String body = response.fields[positionCounter+3].substring(1, response.fields[positionCounter+3].length-1);
                        String timestamp;
                        if (int.tryParse(response.fields[positionCounter+4].substring("TIMESTAMP:".length)) != null) {
                          timestamp = TimeFormatter.toVisualDate(int.parse(response.fields[positionCounter+4].substring("TIMESTAMP:".length)));
                        } else {
                          timestamp = "";
                        }
                        String options = response.fields[positionCounter+5];
                        List<String> optionsSplit = options.split(".");
                        List<String> displayOptions = [];
                        for (String option in optionsSplit) {
                          if (option.length > 2 && option.startsWith('"') && option.endsWith('"')) {
                            String noQuotes = option.substring(1,option.length-1);
                            displayOptions.add(noQuotes);
                          } else {
                            PersistentProtocolConnection().sendDebugMessage("Client received invalid option '"+option+'"');
                          }
                        }
                        notifications.add(createNotificationWidget(notificationType, notificationID, title, body, timestamp, displayOptions));
                      } catch(error) {
                        print("failed to parse notification, error:");
                        print(error.toString());
                        notifications.add(const Text("Failed to parse notification"));
                      }
                      positionCounter += 6;
                    }
                    return ListView(
                        children: notifications
                    );
                  }
                },
                staticRequest: StaticRequest(
                  "REQUESTNOTIFICATIONS",
                  [],
                ),
                stateIdentifier: "NOTIFICATIONSPAGE",
              ),
            )
        )
    );
  }
}

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({Key? key, required this.groupID, required this.groupName}) : super(key: key);
  final String groupID;
  final String groupName;

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  bool isDisposed = false;

  @override
  void initState() {
    super.initState();
    isDisposed = false;
    PersistentProtocolConnection().wipeStateWithID("TRANSACTIONS");
  }

  void forceRebuild() {
    setState(() {
      PersistentProtocolConnection().wipeStateWithID("TRANSACTIONS");
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (PersistentProtocolConnection().spontaneousLogOut) {
      Future.microtask(() {
        Navigator.pop(context);
      });
      return Scaffold(
          appBar: AppBar(
              title: Text("Transactions in household "+widget.groupName)
          ),
          body: Center(
              child: ListView(children: const [SizedBox(height:90),Center(child:Text("Hang on...",style: TextStyle(color:Color(0xffffffff))))])
          )
      );
    }
    //Widget createTransactionsWidget
    return Scaffold(
        appBar: AppBar(
            title: Text("Transactions in household "+widget.groupName)
        ),
        body: Center(
            child: Container(
                color: Colors.lightBlue,
                child: RequestWidget(
                  waitingWidget: ListView(children: const [SizedBox(height:90),Center(child:Text("Loading transactions...",style: TextStyle(color:Color(0xffffffff))))]),
                  errorWidget: ListView(children: const [SizedBox(height:90),Center(child:Text("Failed to load transactions - maybe try reloading the app?",style: TextStyle(color:Color(0xffffffff))))]),
                  loadedWidgetGenerator: (response) {

                  },
                  staticRequest: StaticRequest(
                    "VIEWTRANSACTIONS",
                    ["GROUPID:"+widget.groupID],
                  ),
                  stateIdentifier: "TRANSACTIONS",
                )
            )
        )
    );
  }
}

class LoadingPage extends StatefulWidget {
  const LoadingPage({Key? key}) : super(key: key);

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Offset middle = Offset(100, 100);
  String state = "IDLE";
  // Possible states: IDLE, CHECKINGDISK, AUTHENTICATING, LOGGEDIN, LOGGINGIN

  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    );
    _controller.repeat();
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    /*
    Future.microtask(() => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MyHomePage(title: "Home page"))
    ));

    print("pushed second page to stack");
     */

    return Scaffold(
        appBar: AppBar(
            title:const Text("HousePay (Loading...)")
        ),
        body: Center(
            child: Container(
                color:Colors.lightBlue,
                child: Center(
                    child: AnimatedBuilder(
                        animation: _controller.view,
                        builder: (context, child) {
                          if (PersistentProtocolConnection().connectionState.currentlyLoggedIn && state == "IDLE") {
                            PersistentProtocolConnection().spontaneousLogOut = false;
                            print("set isInLoggedInPartsOfApp to FALSE");
                            PersistentProtocolConnection().isInLoggedInPartsOfApp = false;
                            Future.microtask(() async {
                              print("set isInLoggedInPartsOfApp to TRUE");
                              PersistentProtocolConnection().isInLoggedInPartsOfApp = true;
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const AllGroupsPage())
                              );
                              PersistentProtocolConnection().wipeStateWithID("ALLGROUPSPAGE");
                              state = "IDLE";
                            });
                            print("apparently already logged in, so create microtask for AllGroupsPage");
                            state = "LOGGEDIN";
                          } else if (state == "IDLE" && PersistentProtocolConnection().spontaneousLogOut) {
                            PersistentProtocolConnection().spontaneousLogOut = false;
                            state = "LOGGINGIN";
                            Future.microtask(() async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const LoginPage())
                              );
                              state = "IDLE";
                            });
                          }
                          else if (state == "IDLE" && (PersistentProtocolConnection().connectionState.protocolState == "IDLE" || PersistentProtocolConnection().connectionState.protocolState == "WAITING")) {
                            print("Own state is IDLE, running checks...");
                            PersistentProtocolConnection().getFromDisk("USERNAME").then((username) {
                              print("got username");
                              PersistentProtocolConnection().getFromDisk("ENCRYPTEDPASSWORD").then((encryptedPassword) {
                                print("got password");
                                if (username != null && encryptedPassword != null && encryptedPassword != "") {
                                  PersistentProtocolConnection().hasLoginData = true;
                                  PersistentProtocolConnection().username = username;
                                  PersistentProtocolConnection().password = "";
                                  PersistentProtocolConnection().encryptedPassword = encryptedPassword;
                                  print("sending request...");
                                  PersistentProtocolConnection().addAndSendRequest(Request("LOGIN", ['USERNAME:"'+username+'"','PASSWORD:"'+encryptedPassword+'"'], (response) {
                                    print("got request back");
                                    if (response.fields.length < 2) {
                                      PersistentProtocolConnection().sendDebugMessage("Recieved a LOGIN message, but it had the wrong number of fields: expected LOGIN, SUCCESS/FAILURE, USERID:userID/Reason");
                                      Future.microtask(() async {
                                        await Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (context) => const LoginPage())
                                        );
                                        state = "IDLE";
                                      });
                                      PersistentProtocolConnection().hasLoginData = false;
                                    } else {
                                      if (response.fields[0] == "SUCCESS") {
                                        PersistentProtocolConnection().userID = response.fields[1].substring("USERID:".length);
                                        print("logging in and setting userID");
                                        Future.microtask(() async {
                                          print("set inInLoggedInPartsOfApp to TRUE");
                                          PersistentProtocolConnection().isInLoggedInPartsOfApp = true;
                                          await Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (context) => const AllGroupsPage())
                                          );
                                          PersistentProtocolConnection().wipeStateWithID("ALLGROUPSPAGE");
                                          state = "IDLE";
                                        });
                                        print("added microtask to push to AllGroupsPage");

                                      } else {
                                        //login failed: invalid password?

                                        Future.microtask(() async {
                                          await Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (context) => const LoginPage())
                                          );
                                          state = "IDLE";
                                        });
                                      }
                                    }
                                  }));
                                  state = "AUTHENTICATING";
                                } else {
                                  // no username or password in memory
                                  print("no username or password in memory");
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const LoginPage())
                                  ).then((value) {
                                    state = "IDLE";
                                  });
                                  state = "LOGGINGIN";
                                }
                              });
                            });
                            state = "CHECKINGDISK";
                          }

                          return Transform.rotate(angle: _controller.value * 2 * pi, child:child);
                        },
                        child: Center(
                            child:Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.lightBlue,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                    child: ClipRect(
                                        child:Image.asset("assets/icon/icon.png")
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )
    );
  }
}

class WheelSpin extends StatefulWidget {
  const WheelSpin({Key? key, required this.option1, required this.option2, required this.option3, required this.option4, required this.option5, required this.option6, required this.optionSelected, required this.purchaseName}) : super(key: key);
  final String option1;
  final String option2;
  final String option3;
  final String option4;
  final String option5;
  final String option6;
  final int optionSelected;
  final String purchaseName;

  @override
  State<WheelSpin> createState() => _WheelSpinState();
}

class _WheelSpinState extends State<WheelSpin> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late ConfettiController _controllerCenter;
  bool lockedIn = false;
  int currentPointer = -1;
  double size = 300;
  List<Color> colors = const [
    Colors.orangeAccent,
    Colors.teal,
    Colors.redAccent,
    Colors.deepPurpleAccent,
    Colors.amberAccent,
    Colors.pinkAccent,
  ];
  late List<String> options = [
    widget.option1,
    widget.option2,
    widget.option3,
    widget.option4,
    widget.option5,
    widget.option6
  ];
  int colorPermutation = 0;
  bool isFreeSpinning = false;
  double currentOffset = 0;
  double lastValueVelocity = 0;
  double fixedGoalAngle = 0;
  double stoppingPoint = 0;
  double pointerDownRotation = 0;
  double lastTimeValue = 0;
  double animationSeconds = 1;
  double spinProportion = 0;
  double animationProportion = 0;
  double squashedSize = 48;
  int targetRotations = 6;
  double Function(double) slowDownTransform = (double i) => 1-((1-i)*(1-i));
  double Function(double, Duration) calculateSlowdownRotation = (double velocity, Duration duration) => velocity * (duration.inMicroseconds/Duration.microsecondsPerSecond) / 4;

  double inAnimation(double t) {
    return rangeIn(spinProportion, 1, t);
  }

  @override
  void initState() {
    lockedIn = false;
    _controller = AnimationController(
        vsync: this,
        duration: Duration(seconds:10)
    );
    _controller.value = 1.0;
    colorPermutation = Random().nextInt(6);
    fixedGoalAngle = (1/3)*pi*Random().nextDouble();
    stoppingPoint = Random().nextDouble()*2*pi;
    print("for random permutation, got "+colorPermutation.toString());
    _controller.reset();
    _controllerCenter = ConfettiController(duration: const Duration(seconds:1));
    _controllerCenter.stop();

    super.initState();
  }

  @override void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double calculateDeltaTime() {
    return (_controller.value-lastTimeValue) % 1.0;
  }

  double mostlyRangeIn(double start, double stop, double t) {
    if (t <= start) {
      return 0;
    } else {
      if (t >= stop) {
        return 0.99999999;
      } else {
        return (t-start)/(stop-start);
      }
    }
  }

  double rangeIn(double start, double stop, double t) {
    if (t <= start) {
      return 0;
    } else {
      if (t >= stop) {
        return 1;
      } else {
        return (t-start)/(stop-start);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _controller.repeat();
    return Scaffold(
        appBar: AppBar(
            title: Text("Spin!")
        ),
        body: Container(
          color: Colors.lightBlue,
          child: ListView(
              children: [
                const SizedBox(height:90),

                Center(
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            SizedBox(height:size/2),
                            Align(
                              alignment: Alignment.center,
                              child: ConfettiWidget(
                                confettiController: _controllerCenter,
                                blastDirectionality: BlastDirectionality.explosive,
                                particleDrag: 0.05,
                                numberOfParticles: 50,
                                gravity: 0.05,
                                shouldLoop: false,
                                colors: colors,
                                emissionFrequency: 0,
                              ),
                            ),
                          ],
                        ),
                        Listener(
                          onPointerDown: (PointerDownEvent event) {
                            if (currentPointer == -1) {
                              if (!lockedIn) {
                                Offset centerOffset = event.localPosition - Offset(MediaQuery.of(context).size.width/2,size/2);
                                if (centerOffset.distance <= size / 2) {
                                  currentPointer = event.pointer;
                                  if (isFreeSpinning) {
                                    currentOffset = lerpDouble(currentOffset, 0, slowDownTransform(_controller.value))! % (2*pi);
                                  }
                                  isFreeSpinning = false;
                                  pointerDownRotation = -atan2(centerOffset.dx, centerOffset.dy);
                                  lastValueVelocity = 0;
                                  lastTimeValue = 0;
                                  _controller.duration = Duration(seconds:4);
                                  _controller.repeat();
                                }
                              }
                            }
                          },
                          onPointerMove: (PointerMoveEvent event) {
                            if (event.pointer == currentPointer) {
                              Offset centerOffset = event.localPosition - Offset(MediaQuery.of(context).size.width/2,size/2);
                              double rotation = -atan2(centerOffset.dx, centerOffset.dy);
                              double deltaPointerDown = rotation - pointerDownRotation;
                              pointerDownRotation = rotation;
                              double deltaTime = calculateDeltaTime();
                              if (deltaTime != 0) {
                                lastValueVelocity = deltaPointerDown / deltaTime;
                              }

                              lastTimeValue = _controller.value;
                              currentOffset = (currentOffset + deltaPointerDown) % (2*pi);
                            }
                          },
                          onPointerUp: (PointerUpEvent event) {
                            if (!lockedIn) {
                              if (event.pointer == currentPointer) {
                                currentPointer = -1;
                                isFreeSpinning = true;
                                print("before operating, current offset is "+currentOffset.toString());
                                print("and stopping point is "+stoppingPoint.toString());
                                print("with % sum as "+((currentOffset+stoppingPoint)%(2*pi)).toString());
                                double slowDownSeconds = 4;
                                Duration duration = Duration(milliseconds:(slowDownSeconds*1000).round());
                                double slowDownRotation = -calculateSlowdownRotation(lastValueVelocity, duration);
                                print("calculated slowDownRotation to be "+slowDownRotation.toString());

                                stoppingPoint = (currentOffset+stoppingPoint)%(2*pi) - slowDownRotation;
                                currentOffset = slowDownRotation;

                                int intExtraSpins = stoppingPoint ~/ (2*pi);
                                print("Extra spins: "+intExtraSpins.toString());

                                stoppingPoint = stoppingPoint % (2*pi);

                                print("after operating, current offset is "+currentOffset.toString());
                                print("and stopping point is "+stoppingPoint.toString());
                                print("with % sum as "+((currentOffset+stoppingPoint)%(2*pi)).toString());

                                if (intExtraSpins >= targetRotations || -intExtraSpins >= targetRotations) {
                                  stoppingPoint = fixedGoalAngle;
                                  print("sufficiently fast!");

                                  duration = Duration(microseconds:duration.inMicroseconds+(animationSeconds*2*1000000).round());
                                  Future.delayed(duration).then((dummy) {
                                    print("confetti!");
                                    _controllerCenter.stop();
                                    _controllerCenter.play();
                                  });
                                  lockedIn = true;
                                  spinProportion = slowDownSeconds / (animationSeconds + slowDownSeconds);
                                  animationProportion = animationSeconds / (animationSeconds + slowDownSeconds);
                                } else {
                                  slowDownSeconds = 2;
                                  duration = Duration(milliseconds:(slowDownSeconds*1000).round());
                                  slowDownRotation = -calculateSlowdownRotation(lastValueVelocity, duration);
                                  stoppingPoint = (currentOffset+stoppingPoint)%(2*pi) - slowDownRotation;
                                  currentOffset = slowDownRotation;
                                  stoppingPoint = stoppingPoint % (2*pi);

                                  print("not fast enough!");
                                }

                                _controller.duration = duration;
                                _controller.forward(from:0.0);
                              }
                            }
                          },
                          child: AnimatedBuilder(
                            animation: _controller.view,
                            builder: (context, child) {
                              double spinAngle;
                              double nameFade = 0;
                              double colorMove = 0;
                              double nameCenter = 0;
                              double boxClose = 0;
                              double textFade;
                              Color option1Color = colors[(colorPermutation)%6];
                              Color option2Color = colors[(colorPermutation+1)%6];
                              Color option3Color = colors[(colorPermutation+2)%6];
                              Color option4Color = colors[(colorPermutation+3)%6];
                              Color option5Color = colors[(colorPermutation+4)%6];
                              Color option6Color = colors[(colorPermutation+5)%6];
                              String option1Name = options[(widget.optionSelected-1)%6];
                              String option2Name = options[(widget.optionSelected)%6];
                              String option3Name = options[(widget.optionSelected+1)%6];
                              String option4Name = options[(widget.optionSelected+2)%6];
                              String option5Name = options[(widget.optionSelected+3)%6];
                              String option6Name = options[(widget.optionSelected+4)%6];
                              if (isFreeSpinning) {
                                if (lockedIn) {
                                  spinAngle = stoppingPoint + lerpDouble(currentOffset, 0, slowDownTransform(rangeIn(0,spinProportion,_controller.value)))!;
                                  colorMove = slowDownTransform(rangeIn(0.3,0.6,inAnimation(_controller.value)));
                                  nameFade = rangeIn(0,0.3,inAnimation(_controller.value));
                                  nameCenter = slowDownTransform(rangeIn(0.6,0.9,inAnimation(_controller.value)));
                                  boxClose = slowDownTransform(rangeIn(0.7,1.0,inAnimation(_controller.value)));
                                  textFade = 1.0;
                                } else {
                                  textFade = _controller.value;
                                  spinAngle = stoppingPoint + lerpDouble(currentOffset, 0, slowDownTransform(_controller.value))!;
                                }
                              } else {
                                textFade = 1.0;
                                spinAngle = currentOffset + stoppingPoint;
                              }
                              return Column(
                                children: [
                                  SizedBox(height: lerpDouble(0, (size-48)/2, boxClose)),
                                  Align(
                                    heightFactor: lerpDouble(1, 48/size, boxClose),
                                    child: Container(
                                      height: size,
                                      width: size,
                                      child: CustomPaint(
                                        size: Size(size, size),
                                        painter: WheelPainter(_controller,
                                          spinAngle,
                                          nameFade,
                                          colorMove,
                                          nameCenter,
                                          boxClose,
                                          textFade,
                                          option1Color,
                                          option2Color,
                                          option3Color,
                                          option4Color,
                                          option5Color,
                                          option6Color,
                                          option1Name,
                                          option2Name,
                                          option3Name,
                                          option4Name,
                                          option5Name,
                                          option6Name,
                                          widget.purchaseName,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    )
                )
              ]
          ),
        )
    );
  }
}

class WheelPainter extends CustomPainter {
  late AnimationController controller;
  late double spinAngle;
  late double nameFade;
  late double colorMove;
  late double nameCenter;
  late double boxClose;
  late double textFade;
  late Color option1Color;
  late Color option2Color;
  late Color option3Color;
  late Color option4Color;
  late Color option5Color;
  late Color option6Color;
  late String option1Name;
  late String option2Name;
  late String option3Name;
  late String option4Name;
  late String option5Name;
  late String option6Name;
  late String purchaseName;


  WheelPainter(this.controller, this.spinAngle, this.nameFade, this.colorMove, this.nameCenter, this.boxClose, this.textFade, this.option1Color, this.option2Color, this.option3Color, this.option4Color, this.option5Color, this.option6Color, this.option1Name, this.option2Name, this.option3Name, this.option4Name, this.option5Name, this.option6Name, this.purchaseName) : super();

  @override
  void paint(Canvas canvas, Size size) {
    //_paintSector(canvas, size, 0, pi/4, Colors.red);
    double textPadding = 5;

    TextPainter textPaint = TextPainter(
      text: TextSpan(text: "Your purchase\n'"+purchaseName+"'\nis paid by", style: TextStyle(fontSize: 18, color: Color(0xffffffff))),
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: "...",
      textAlign: TextAlign.center,
    );


    textPaint.layout(maxWidth: (size.width));
    textPaint.paint(canvas, Offset((size.width-textPaint.width)/2,lerpDouble(-textPaint.height-textPadding, -textPaint.height-24-textPadding+(size.width/2), boxClose)!));

    TextPainter spinFasterPaint = TextPainter(
      text: TextSpan(text: "Spin faster!", style: TextStyle(fontSize: 18, color: Color(0xffffffff).withOpacity(1-textFade))),
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: "...",
      textAlign: TextAlign.center,
    );

    spinFasterPaint.layout();
    spinFasterPaint.paint(canvas, Offset((size.width/2)-(spinFasterPaint.width/2),size.width));

    final paint = Paint()
      ..color = const Color(0xffffffff)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    Offset center = Offset(size.width / 2, size.width / 2);
    double radius = size.width / 2;
    Path path = Path()
      ..moveTo((size.width/2)+(textPaint.width/2)-15, (-textPaint.height/6)-textPadding+lerpDouble(0,(size.width/2)-24, boxClose)!)
      ..lineTo(size.width+24, (-textPaint.height/6)+-textPadding+lerpDouble(0,(size.width/2)-24, boxClose)!)
      ..lineTo(size.width+24, size.width/2)
      ..lineTo(size.width+textPadding, size.width/2);
    canvas.drawPath(path, paint);

    if (colorMove < 0.999999) {
      paintSector(canvas, size, option1Color, 1);
      paintSector(canvas, size, option2Color, 2);
      paintSector(canvas, size, option3Color, 3);
      paintSector(canvas, size, option4Color, 4);
      paintSector(canvas, size, option5Color, 5);
      paintSector(canvas, size, option6Color, 6);
    } else {
      canvas.clipRect(Rect.fromCenter(center: Offset(size.width/2, size.width/2), width: size.width*2, height: lerpDouble(size.width, 48, boxClose)!));
      paintCircle(canvas, size, option1Color);
    }




    _paintRotatedText(canvas, size, ((0/3)+(1/6))*pi, option1Name, Colors.white.withOpacity(1), true);
    _paintRotatedText(canvas, size, ((1/3)+(1/6))*pi, option2Name, Colors.white.withOpacity(1 - nameFade), false);
    _paintRotatedText(canvas, size, ((2/3)+(1/6))*pi, option3Name, Colors.white.withOpacity(1 - nameFade), false );
    _paintRotatedText(canvas, size, ((3/3)+(1/6))*pi, option4Name, Colors.white.withOpacity(1 - nameFade), false);
    _paintRotatedText(canvas, size, ((4/3)+(1/6))*pi, option5Name, Colors.white.withOpacity(1 - nameFade), false);
    _paintRotatedText(canvas, size, ((5/3)+(1/6))*pi, option6Name, Colors.white.withOpacity(1 - nameFade), false);

  }



  void paintSector(Canvas canvas, Size size, Color color, int sectorNumber) {
    if (sectorNumber == 1) {
      _paintSector(canvas, size, spinAngle + lerpDouble(0, (5/6)*pi, colorMove)!, lerpDouble(-(1/3)*pi,-2*pi, colorMove)!, color);
    } else {
      _paintSector(canvas, size, spinAngle + lerpDouble(0, (5/6)*pi, colorMove)! + ((sectorNumber - 2) * lerpDouble((1/3)*pi, 0, colorMove)!), lerpDouble((1/3)*pi,0,colorMove)!, color);
    }
  }

  void _paintRotatedText(Canvas canvas, Size size, double angle, String text, Color color, bool isOption1) {

    TextPainter paint = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: 18, color: color)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: "...",
    );
    print("Printing rotated text '"+text+"' with color of "+color.toString());
    double midPadding = 24;
    double radiusPadding = 5;

    paint.layout(maxWidth: (size.width/2) - midPadding - radiusPadding);

    if (paint.didExceedMaxLines) {
      print("exceeded");
      paint = TextPainter(
        text: TextSpan(text: text, style: TextStyle(color: color)),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: "...",
      );

      double midPadding = 24;
      double radiusPadding = 5;

      paint.layout(maxWidth: (size.width/2) - midPadding - radiusPadding);

    }
    //paint.layout();

    canvas.save();
    canvas.translate(size.width / 2, size.width / 2);
    if (isOption1) {
      if (spinAngle-angle < pi) {
        canvas.rotate(lerpDouble(spinAngle-angle, 0, nameCenter)!);
      } else {
        canvas.rotate(lerpDouble(-(pi*2)+spinAngle-angle, 0, nameCenter)!);
      }
      paint.paint(canvas, Offset.lerp(Offset(midPadding,-paint.height/2),Offset(- paint.width/2,- paint.height/2),nameCenter)!);
    } else {
      canvas.rotate(spinAngle-angle);
      paint.paint(canvas, Offset(midPadding,-paint.height/2));
    }

    canvas.restore();
  }

  void _paintSector(Canvas canvas, Size size, double arcStart, double arcLength, Color color) {

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    Offset center = Offset(size.width / 2, size.width / 2);
    double radius = size.width / 2;
    Rect rect = Rect.fromCircle(center: center, radius: radius);
    Path path = Path()
      ..moveTo(center.dy, center.dy)
      ..arcTo(rect, arcStart, arcLength, false)
      ..close();
    canvas.drawPath(path, paint);
  }

  void paintCircle(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    Offset center = Offset(size.width / 2, size.width / 2);
    double radius = size.width / 2;

    canvas.drawCircle(center, radius, paint);
  }

  Path sectorPath() {
    Offset center = Offset(100, 100);
    double radius = 100;
    Rect rect = Rect.fromCircle(center: center, radius: radius);
    Path path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(rect, pi / 4, pi / 2, false)
      ..close();
    return path;
  }

  @override
  bool shouldRepaint(CustomPainter old) {
    return true;
  }
}

class EnterTransactionPage extends StatefulWidget {
  const EnterTransactionPage({Key? key, required this.groupID}) : super(key: key);
  final String groupID;

  @override
  State<EnterTransactionPage> createState() => _EnterTransactionPageState();
}

class _EnterTransactionPageState extends State<EnterTransactionPage> {
  bool isDisposed = false;
  bool waitingForServer = false;
  String feedback = "";
  String enteredAmount = "";
  String purchaseTitle = "";

  @override
  void initState() {
    isDisposed = false;
    waitingForServer = false;
    feedback = "";
    enteredAmount = "";
    purchaseTitle = "";
    super.initState();
  }

  @override
  void dispose() {
    isDisposed = true;
    super.dispose();
  }

  void _setServerWaiting(bool value) {
    setState(() {
      waitingForServer = value;
    });
  }

  void _setFeedback(String string) {
    setState(() {
      feedback = string;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (PersistentProtocolConnection().spontaneousLogOut) {
      Future.microtask(() {
        Navigator.pop(context);
      });
      return Scaffold(
          appBar: AppBar(
              title: const Text("Enter Transaction")
          ),
          body: const Center(
              child: Text("Hang on...")
          )
      );
    }
    void enterTransaction(int amountPennies) {
      print("enterTransaction called");
      _setFeedback("Entering transaction...");
      _setServerWaiting(true);
      PersistentProtocolConnection().addAndSendRequest(Request(
          "ENTERTRANSACTION",
          ["AMOUNT:"+amountPennies.toString(),"GROUPID:"+widget.groupID,'"'+purchaseTitle+'"'],
              (response) async {
            if (response.fields.length == 8 && response.fields[0] == "SUCCESS" && response.fields[1].startsWith("OPTIONSELECTED:") && response.fields[1].length == 'OPTIONSELECTED:X'.length
                && response.fields[2].length > 2
                && response.fields[3].length > 2
                && response.fields[4].length > 2
                && response.fields[5].length > 2
                && response.fields[6].length > 2
                && response.fields[7].length > 2) {
              if (int.tryParse(response.fields[1].substring("OPTIONSELECTED:".length)) != null) {
                int selected = int.parse(response.fields[1].substring("OPTIONSELECTED:".length));
                if (selected >= 1 && selected <= 6) {
                  _setFeedback("Opening spinner...");
                  await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => WheelSpin(
                        option1: response.fields[2].substring(1,response.fields[2].length-1),
                        option2: response.fields[3].substring(1,response.fields[3].length-1),
                        option3: response.fields[4].substring(1,response.fields[4].length-1),
                        option4: response.fields[5].substring(1,response.fields[5].length-1),
                        option5: response.fields[6].substring(1,response.fields[6].length-1),
                        option6: response.fields[7].substring(1,response.fields[7].length-1),
                        purchaseName: purchaseTitle,
                        optionSelected: selected,
                      ))
                  );
                  Navigator.pop(context);
                  return;
                }
              }
              _setFeedback("This transaction succeeded, but response parsing failed - to see the results, go to the page for this household");
              PersistentProtocolConnection().sendDebugMessage("Client received wrongly-formatted ENTERTRANSACTION response");
            } else if (response.fields.length == 2 && response.fields[0] == "FAILURE" && response.fields[1].length > 2) {
              _setFeedback(response.fields[1].substring(1,response.fields[1].length-1));
            } else if (response.fields.length > 0 && response.fields[0] == "SUCCESS") {
              _setFeedback("This transaction succeeded, but response parsing failed - to see the results, go to the page for this household");
              PersistentProtocolConnection().sendDebugMessage("Client received wrongly-formatted ENTERTRANSACTION response");
            } else if (response.fields.length > 0 && response.fields[0] == "FAILURE") {
              PersistentProtocolConnection().sendDebugMessage("Client received wrongly-formatted ENTERTRANSACTION response (server did not specify failure)");
              _setFeedback("This transaction failed, but the server didn't give a reason");
            } else {
              PersistentProtocolConnection().sendDebugMessage("Client received wrongly-formatted ENTERTRANSACTION response (did not match SUCCESS or FAILURE)");
              _setFeedback("Something went wrong, and we don't know if your transaction succeeded or not - check the page for this household to see cureent balances");
            }
            _setServerWaiting(false);
          }
      ));
    }
    void submitForm() {
      print("submit form called");
      if (purchaseTitle.contains('"')) {
        _setFeedback("Purchase title cannot contain \"");
        return;
      }
      List<String> splitAmount = enteredAmount.split(".");
      int amountPoundsOnly;
      int amountPenceOnly;
      if (splitAmount.length == 1) {
        if (int.tryParse(splitAmount[0]) != null) {
          if (int.parse(splitAmount[0]) < 100 && int.parse(splitAmount[0]) > 0) {
            amountPoundsOnly = int.parse(splitAmount[0]);
            amountPenceOnly = 0;
            enterTransaction(amountPoundsOnly*100);
          } else {
            _setFeedback("Invalid amount £"+int.parse(splitAmount[0]).toString()+" entered");
          }
        } else {
          _setFeedback("Invalid amount '£"+splitAmount[0]+"' entered");
        }
      } else if (splitAmount.length == 2) {
        if (splitAmount[1].length == 1) {
          splitAmount[1] += "0";
        }
        if (int.tryParse(splitAmount[0]) != null && int.tryParse(splitAmount[1]) != null) {
          amountPoundsOnly = int.parse(splitAmount[0]);
          amountPenceOnly = int.parse(splitAmount[1]);
          if (amountPoundsOnly >= 0 && amountPenceOnly >= 0 && (amountPoundsOnly > 0 || amountPenceOnly > 0) && amountPenceOnly < 100) {
            print("adding budget (pounds and pence)");
            enterTransaction((amountPoundsOnly*100)+amountPenceOnly);
          } else {
            _setFeedback("Invalid '£"+amountPoundsOnly.toString()+"."+amountPenceOnly.toString()+" entered");
          }
        } else {
          _setFeedback("Invalid amount '£"+splitAmount[0]+"."+splitAmount[1]+"' entered");
        }
      } else {
        _setFeedback("Invalid amount entered - could not parse");
      }
    };
    return Scaffold(
        appBar: AppBar(
            title: Text("Enter Transaction")
        ),
        body: Center(
            child: Column(
              children: [
                SizedBox(height:30),
                Row(
                  children: [
                    const Text("£"),
                    Expanded(
                      child: TextField(
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Enter amount'
                          ),
                          onChanged: (entered) {
                            enteredAmount = entered;
                          }
                      ),
                    ),
                  ],
                ),
                Text(feedback),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Enter purchase title'
                        ),
                        onChanged: (entered) {
                          purchaseTitle = entered;
                          if (purchaseTitle.contains('\"')) {
                            _setFeedback("Purchase title cannot contain \"");
                          }
                        },
                        onSubmitted: waitingForServer ? null : (dummy) => submitForm(),
                      ),
                    ),
                    ElevatedButton(
                      child: Text("Enter"),
                      onPressed: waitingForServer ? null : submitForm,
                    ),
                  ],
                ),
              ],
            )
        )
    );
  }
}

class BetterLoadingPage extends StatefulWidget {
  const BetterLoadingPage({Key? key}) : super(key: key);

  @override
  State<BetterLoadingPage> createState() => _BetterLoadingPageState();
}

class _BetterLoadingPageState extends State<BetterLoadingPage> {
  String feedback = "Loading...";
  bool isDisposed = false;
  bool isLoaded = true;

  @override
  void initState() {
    isDisposed = false;
    feedback = "";
    super.initState();
  }

  @override
  void dispose() {
    isDisposed = false;
    super.dispose();
  }

  void _setFeedback(String string) {
    setState(() {
      feedback = string;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: Text("HousePay (Loading...)")
        )
    );
  }


}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headline4,
            ),
            RequestWidget(
                waitingWidget: Text("Waiting"),
                errorWidget: Text("Error"),
                loadedWidgetGenerator: (Response response) {
                  return Text(response.fields.toString());
                },
                staticRequest: StaticRequest("LOGIN", <String>[]),
                stateIdentifier: "loginpage")
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}