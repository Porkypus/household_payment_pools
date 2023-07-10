package server;

import DatabaseComm.MySqlCon;
import financialModel.FinanceModel;
import financialModel.Liable;
import financialModel.ReturnInfo;

import java.io.*;
import java.math.BigDecimal;
import java.net.Socket;
import java.util.*;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

import static financialModel.FinanceModel.sha256;

public class ClientHandler {
	private final LinkedBlockingQueue<ArrayList<String>> queueRequest = new LinkedBlockingQueue<>();
	private final LinkedBlockingQueue<Response> queueResponse = new LinkedBlockingQueue<>();
	Stage stage = Stage.CONNECTED;
	Integer uid;
	boolean connected = true;

	public ClientHandler(Connection connection, MySqlCon database) throws IOException {
		Socket socket = connection.socket;

		BufferedWriter out = new BufferedWriter(new OutputStreamWriter(socket.getOutputStream()));
		BufferedReader in = new BufferedReader(new InputStreamReader(socket.getInputStream()));

		queueResponse.add(new ConnectedResponse());                   // add special connection message to send queue

		// This thread directly reads input from the client
		/*
		 ** now allows arbitrary strings, but these can continue indefinitely (see above note) **
		 */
		Thread receive = new Thread(() -> {
			try {
				ArrayList<String> sections = new ArrayList<>();     // list of sections in current packet
				StringBuilder sb = new StringBuilder();             // buffer for characters
				boolean string = false;                             // indicates whether currently reading within '"'s - ignores '<' and '>'
				while (connected) {
					char c = (char) in.read();                       // read in one character
					if (sections.isEmpty()) {                       // if first section
						if (sb.length() == 0) {                     // if start of message
							if (c == '<') {
								c = (char) in.read();               // start message at character following '<'
							} else {
								continue;
							}
						} else {                                      // if first section doesn't match any request strings
							if (Arrays.stream(Message.values()).noneMatch(r -> r.string.startsWith(sb.toString()))) {
								while (c != '<' && c != '>') {
									sb.append(c);
									c = (char) in.read();
								}
								if (c == '>') {
									sections.add(Message.INVALID.string);
								}
							} else if (c == '>' && (!sb.toString().equals(Message.HANDSHAKESUCCESSFUL.string) && !sb.toString().equals(Message.HOUSEPAYCLIENT.string))) {
								sections.add(Message.INVALID.string);
							}
						}
					}
					if (c == '>' && !string) {                      // if end of message
						sections.add(sb.toString());
						queueRequest.add(sections);                 // add input to request queue
						sb.setLength(0);                            // then clear the buffer
						sections = new ArrayList<>();
					} else if (c == '<' && !string) {                 // if '<' within message
						sb.setLength(0);                            // ignore previous characters and start message again
						sections.clear();
					} else if (c == ',' && !string) {                 // if ','
						sections.add(sb.toString());                // end section
						sb.setLength(0);
					} else if (c == '"') {                            // if '"'
						string = !string;                           // either start or end of string
						sb.append(c);
					} else {
						sb.append(c);                               // add character to buffer

					}
				}
			} catch (IOException e) {
				connected = false;
				e.printStackTrace();
			}
		});
		receive.setDaemon(true);
		receive.start();

		// This thread directly sends messages to the client
		Thread send = new Thread(() -> {
			try {
				while (connected) {
					String s = queueResponse.take().string;
					out.write(s);         // send next response in queue, otherwise block until available
					out.flush();
				}
			} catch (IOException | InterruptedException e) {
				connected = false;
				e.printStackTrace();
			}
		});
		send.setDaemon(true);
		send.start();

		// This thread processes a request from the client and creates a response
		Thread process = new Thread(() -> {
			try {
				int currentRequestID = Integer.MIN_VALUE;           // not sure this is best place to initialise this
				while (connected) {
					List<String> request = queueRequest.poll(30, TimeUnit.SECONDS);     // first request in queue
					if (request == null) {
						if (stage == Stage.CONNECTED || stage == Stage.HANDSHAKE) {
							queueResponse.add(new HandshakeFailResponse("Timeout: no response in 30 seconds"));
							socket.close();
						}
						continue;
					}
					switch (stage) {
						case CONNECTED -> {
							switch (Message.valueOf(request.get(0))) {
								case DEBUG -> System.out.println(request.get(1)); //Debugging
								case HOUSEPAYCLIENT -> { //Initial message from client
									queueResponse.add(new HandshakeSuccessfulResponse());
									stage = Stage.HANDSHAKE;
								}
								default -> { //Invalid actions
									queueResponse.add(new InvalidFormatResponse("<HOUSEPAYCLIENT>", request));
									socket.close();
								}
							}
						}
						case HANDSHAKE -> {                                 // setting up (handshake)
							switch (Message.valueOf(request.get(0))) {
								case DEBUG -> System.out.println(request.get(1)); //Debugging
								case HANDSHAKESUCCESSFUL -> stage = Stage.LOGGEDOUT; //Entering running phase
								default -> { //Invalid actions
									queueResponse.add(new InvalidFormatResponse("<HANDSHAKESUCCESSFUL>", request));
									socket.close();
								}
							}
						}
						case LOGGEDOUT -> {
							switch (Message.valueOf(request.get(0))) {
								case DEBUG -> System.out.println(request.get(1));
								case REQUEST -> {
									if (request.size() < 2) {
										queueResponse.add(new InvalidFormatResponse("<REQUEST,REQUESTID:num,...>", request));
										continue;
									}
									int requestID;
									try {
										requestID = Integer.parseInt(request.get(1).substring(10));
									} catch (Exception e) {
										queueResponse.add(new InvalidFormatResponse("<REQUEST,REQUESTID:num,...>", request));
										continue;
									}
									if (requestID <= currentRequestID) {
										queueResponse.add(new DebugResponse("Request ID unordered"));
										continue;
									}
									currentRequestID = requestID;
									if (request.size() < 3) {
										queueResponse.add(new InvalidFormatResponse("<REQUEST,REQUESTID:NUM,REQUESTTYPE,...>", request));
										continue;
									}
									try {
										switch (Request.valueOf(request.get(2))) {
											case CREATEUSERACCOUNT -> {
												if (request.size() != 5) {
													queueResponse.add(new CreateUserAccountResponse("Expecting: <REQUEST,REQUESTID:NUM,CREATEUSERACCOUNT,\"username\",\"password\">, but got: <" + String.join(",", request) + ">", request.get(1)));
													continue;
												}
												try {
													if (request.get(3).charAt(0) != '\"' || request.get(3).charAt(request.get(3).length() - 1) != '\"' || request.get(3).substring(1, request.get(3).length() - 1).contains("\"") || request.get(4).charAt(0) != '\"' || request.get(4).charAt(request.get(4).length() - 1) != '\"' || request.get(4).substring(1, request.get(4).length() - 1).contains("\"")) {
														queueResponse.add(new CreateUserAccountResponse("Expecting: <REQUEST,REQUESTID:NUM,CREATEUSERACCOUNT,\"username\",\"password\">, but got: <" + String.join(",", request) + ">", request.get(1)));
														continue;
													}
													uid = database.getUid(request.get(3).substring(1, request.get(3).length() - 1));
													if (uid == null) {

														uid = database.createUser(request.get(3).substring(1, request.get(3).length() - 1), sha256(request.get(4).substring(1, request.get(4).length() - 1)));
														queueResponse.add(new CreateUserAccountResponse(uid, request.get(1)));
													} else {
														queueResponse.add(new CreateUserAccountResponse("Chosen username is taken.", request.get(1)));
													}
												} catch (IndexOutOfBoundsException e) {
													queueResponse.add(new CreateUserAccountResponse("Expecting: <REQUEST,REQUESTID:NUM,CREATEUSERACCOUNT,\"username\",\"password\">, but got: <" + String.join(",", request) + ">", request.get(1)));
												}
											}
											case LOGIN -> {
												if (request.size() != 5) {
													queueResponse.add(new LoginResponse("Expecting: <REQUEST,REQUESTID:NUM,LOGIN,USERNAME:\"username\",PASSWORD:\"password\">, but got: <" + String.join(",", request) + ">", request.get(1)));
													continue;
												}
												try {
													uid = database.getUid(request.get(3).substring(10, request.get(3).length() - 1));
													if (uid == null) {
														queueResponse.add(new LoginResponse("Unknown username.", request.get(1)));
														continue;
													}
													String password = database.getUserPassword(uid);
													if (!Objects.equals(password, sha256(request.get(4).substring(10, request.get(4).length() - 1)))) {
														queueResponse.add(new LoginResponse("Wrong password.", request.get(1)));
														continue;
													}
													queueResponse.add(new LoginResponse(uid, request.get(1)));
													stage = Stage.LOGGEDIN;
												} catch (IndexOutOfBoundsException e) {
													queueResponse.add(new LoginResponse("Expecting: <REQUEST,REQUESTID:NUM,LOGIN,USERNAME:\"username\",PASSWORD:\"password\">, but got: <" + String.join(",", request) + ">", request.get(1)));
												}
											}
											case LOGOUT -> queueResponse.add(new LogoutResponse(true, request.get(1)));
											case CREATEGROUP -> queueResponse.add(new CreateGroupResponse("Cannot create group while logged out", request.get(1)));
											case GETUSERBYNAME -> queueResponse.add(new GetUserByNameResponse("Cannot get userID while logged out", request.get(1)));
											case GETUSERBYUSERID -> queueResponse.add(new GetUserByUserIDResponse("Cannot get user by ID while logged out", request.get(1)));
											case INVITEUSERTOGROUP -> queueResponse.add(new InviteUserToGroupResponse("Cannot invite user to group while logged out", request.get(1)));
											case GETGROUPINFO -> queueResponse.add(new GetGroupInfoResponse(false,"Cannot get group info while logged out", request.get(1)));
											case SETGROUPSETTING -> queueResponse.add(new SetGroupSettingResponse(false, "Cannot set group setting while logged out", request.get(1)));
											case REMOVEUSER -> queueResponse.add(new RemoveUserReponse("Cannot remove user from group while logged out", request.get(1)));
											case ENTERTRANSACTION -> queueResponse.add(new EnterTransactionResponse(false, "Cannot enter transaction while logged out", request.get(1)));
											case ADDBUDGET -> queueResponse.add(new AddBudgetResponse("Cannot add budget while logged out", request.get(1)));
											case SETPERSONALSETTING -> queueResponse.add(new SetPersonalSettingResponse(false,"Cannot change username or password while logged out", request.get(1)));
											case NOTIFICATIONRESPONSE -> queueResponse.add(new NotificationResponseResponse("Cannot respond to a notification while logged out", request.get(1)));
											case REQUESTNOTIFICATIONS -> queueResponse.add(new RequestNotificationsResponse("Cannot get notifications while logged out",request.get(1)));
											case VIEWTRANSACTIONS -> queueResponse.add(new ViewTransactionsResponse("Cannot view transactions while logged out", request.get(1)));
											case GETSTATUS -> queueResponse.add(new GetStatusResponse(false,"Cannot get status while logged out", request.get(1)));
											default -> queueResponse.add(new InvalidFormatResponse("<REQUEST,REQUESTID:num,LOGIN,...>", request));
										}
									} catch (IllegalArgumentException e) {
										queueResponse.add(new InvalidFormatResponse("<REQUEST,REQUESTID:num,LOGIN/CREATEUSERACCOUNT,...>", request));
									}
								}
								default -> queueResponse.add(new InvalidFormatResponse("<REQUEST,...>", request));
							}
						}
						case LOGGEDIN -> {
							switch (Message.valueOf(request.get(0))) {
								case DEBUG -> System.out.println(request.get(1));
								case REQUEST -> {
									if (request.size() < 2) {
										queueResponse.add(new InvalidFormatResponse("<REQUEST,REQUESTID:num,...>", request));
										continue;
									}
									int requestID;
									try {
										requestID = Integer.parseInt(request.get(1).substring(10));
									} catch (Exception e) {
										queueResponse.add(new InvalidFormatResponse("<REQUEST,REQUESTID:num,...>", request));
										continue;
									}
									if (requestID <= currentRequestID) {
										queueResponse.add(new DebugResponse("Request ID unordered"));
										continue;
									}
									currentRequestID = requestID;
									if (request.size() < 3) {
										queueResponse.add(new InvalidFormatResponse("<REQUEST,REQUESTID:num,REQUESTTYPE,...>", request));
										continue;
									}
									try {
										switch (Request.valueOf(request.get(2))) {
											case LOGOUT -> {
												if (request.size() != 3) {
													queueResponse.add(new LogoutResponse(false, request.get(1)));
													continue;
												}
												uid = null;
												stage = Stage.LOGGEDOUT;
												queueResponse.add(new LogoutResponse(true, request.get(1)));
											}
											case CREATEGROUP -> {
												int groupID = database.createHousehold(request.get(3).substring(1, request.get(3).length() - 1), uid);
												if (groupID != -1 && database.addToHousehold(uid, groupID)) {
													queueResponse.add(new CreateGroupResponse(groupID, request.get(1)));
												} else {
													queueResponse.add(new CreateGroupResponse("", request.get(1)));
													// Database may return reason for failure we can add
												}
											}
											case GETUSERBYNAME -> {           // why do we need this?
												String name = request.get(3).substring(1, request.get(3).length() - 1);
												Integer userID = database.getUid(name);
												if (userID != null) {
													queueResponse.add(new GetUserByNameResponse(userID, name, request.get(1)));
												} else {
													queueResponse.add(new GetUserByNameResponse("No user exists with this name",request.get(1)));
												}
											}
											case GETUSERBYUSERID -> {
												int userID = Integer.parseInt(request.get(3).substring(7));
												String userName = database.getUserUName(userID);
												if (userName != null) {
													queueResponse.add(new GetUserByUserIDResponse(userID, userName, request.get(1)));
												} else {
													queueResponse.add(new GetUserByUserIDResponse("No user exists with this userID",request.get(1)));
												}
											}
											case INVITEUSERTOGROUP -> {
												int recipientID = Integer.parseInt(request.get(3).substring(7));
												if (recipientID==uid) {
													queueResponse.add(new InviteUserToGroupResponse("You cannot invite yourself",request.get(1)));
												}
												else {
													int groupID = Integer.parseInt(request.get(4).substring(8));
													if (database.getAllUsers(groupID).contains(recipientID)){
														queueResponse.add(new InviteUserToGroupResponse("You cannot invite a person already in the group",request.get(1)));

													}
													if (!database.getInvite(groupID, recipientID)) {
														if (database.createInvite(groupID, recipientID)) {
															queueResponse.add(new InviteUserToGroupResponse(request.get(1)));
															String groupName = database.getHouseholdName(groupID);
															String userName = database.getUserUName(uid);
															sendNotification(this, new Notification(recipientID, Notification.NotificationType.GROUPINVITE, "Group Invite", userName + " has invited you to join '" + groupName + "'", "\"accept\".\"dismiss\".\"hidden:" + groupID + "\""), database);
														} else {
															queueResponse.add(new InviteUserToGroupResponse("", request.get(1))); // not sure where failure message should come from
														}
													} else
														queueResponse.add(new InviteUserToGroupResponse("User already has invite from this group", request.get(1)));
												}
											}
											case GETGROUPINFO -> {
												int groupID = Integer.parseInt(request.get(3).substring(8));
												List<String> info = new LinkedList<>();
												String name = database.getHouseholdName(groupID);
												Integer adminUID = database.getHouseholdLeader(groupID);
												List<Integer> groupMembers = database.getAllUsers(groupID);
												if ((name == null) | (adminUID == null) | (groupMembers == null)) {
													queueResponse.add(new GetGroupInfoResponse(false,"Failed to load household info - maybe try reloading the app?",request.get(1)));   // Unsure why null is passed here?
													continue;
												}
												info.add("\"" + name + "\"");
												info.add("ADMIN:" + adminUID);
												for (Integer member : groupMembers) {
													Integer budget = database.getUserBudget(member, groupID);
													String username = database.getUserUName(member);
													info.add("MEMBER:" + member + ",NAME:\"" + username + "\",BUDGET:" + budget);
												}
												String message = String.join(",", info);
												queueResponse.add(new GetGroupInfoResponse(true, message, request.get(1)));
											}
											case SETGROUPSETTING -> {
												int groupID = Integer.parseInt(request.get(3).substring(8));
												// Not 100% sure the format of the setting-value pairs
												// Assuming just : separating
												boolean validated = true;
												if (!(Objects.equals(database.getHouseholdLeader(groupID), uid))) {
													queueResponse.add(new SetGroupSettingResponse(false, "\"Only group admin may edit group settings\"", request.get(1)));
													continue;
												}
												for (String item : request.subList(4, request.size())) {
													String[] pair = item.split(":");
													if (pair.length != 2) {
														queueResponse.add(new SetGroupSettingResponse(false, "\"Invalid input\"", request.get(1)));
														continue;
													} if (Objects.equals(pair[0], "ADMIN")) {
														int userID = Integer.parseInt(pair[1]);
														if (database.getUserUName(userID) == null || !database.getAllUsers(groupID).contains(userID)) {
															validated = false;  // this user does not exist, or is not in the group
															queueResponse.add(new SetGroupSettingResponse(false, "\"User does not exist or is not in group\"", request.get(1)));
															break;
														}
													} else if (Objects.equals(pair[0], "NAME")) {
														// unsure if we need to add any constraints on group name
													} else {
														validated = false; // if they try to set something not settable
														queueResponse.add(new SetGroupSettingResponse(false, "\"Update failed\"", request.get(1)));
														break;
													}
												}
												if (validated) {
													for (String item : request.subList(4, request.size())) {
														String[] pair = item.split(":");
														if (Objects.equals(pair[0], "NAME")) {
															if (!database.setHouseholdName(groupID, pair[1])) {
																queueResponse.add(new SetGroupSettingResponse(false, "\"Update failed\"", request.get(1)));
																break;  // I think we should break out as soon as possible - no more changes
															}
														} else if (Objects.equals(pair[0], "ADMIN")) {
															if (!database.setHouseholdLeader(groupID, Integer.parseInt(pair[1]))) {
																queueResponse.add(new SetPersonalSettingResponse(false, "\"Update failed\"", request.get(1)));
																break;
															}
														}
													}
													queueResponse.add(new SetGroupSettingResponse(true, String.join(",", request.subList(4, request.size())), request.get(1)));
												}
											}
											case REMOVEUSER -> {
												int userIDToRemove = Integer.parseInt(request.get(3).substring(7));
												int groupID = Integer.parseInt(request.get(4).substring(8));
												if (database.getHouseholdLeader(groupID)==userIDToRemove) {
													queueResponse.add(new RemoveUserReponse("Cannot remove admin, change admin first",request.get(1)));
												}
												else{
													if (database.getAllUsers(groupID).contains(userIDToRemove)) {
														if (database.deleteUserMembersEntry(groupID, userIDToRemove)) {
															sendNotification(this, new Notification(userIDToRemove, Notification.NotificationType.REMOVEDFROMGROUP, "Removed from group", database.getUserUName(uid) + " has removed you from the group " + database.getHouseholdName(groupID), "\"dismiss\".\"hidden:" + groupID + "\""), database);
															queueResponse.add(new RemoveUserReponse(request.get(1)));
														} else {
															queueResponse.add(new RemoveUserReponse("Attempt to remove user failed", request.get(1)));
														}
													} else {
														queueResponse.add(new RemoveUserReponse("User not in group", request.get(1)));
													}
												}
											}
											case ENTERTRANSACTION -> {
												int amount = Integer.parseInt(request.get(3).substring(7));
												int gid = Integer.parseInt(request.get(4).substring(8));
												String title = request.get(5).substring(1, request.get(5).length() - 1);
												//title = title.substring(1, title.length() - 1);
												ReturnInfo info = FinanceModel.pay(uid, gid, amount);
												if (info.getStatus().equals("FAILURE")) {
													queueResponse.add(new EnterTransactionResponse(false, "Transaction failed", request.get(1)));
													continue;
												}
												if (title.equals("")) {
													queueResponse.add(new EnterTransactionResponse(false, "Transaction requires title", request.get(1)));
													continue;
												}
												List<Liable> chargedUsers = info.getLiables();
												List<List<Integer>> uidsForSpinner = info.getUuids();
												// Create transaction (uid, gid, amount)
												Integer tid = database.createTransaction(title,info.getPayer(), info.getHid(), info.getPaid());
												if (tid == null) {
													queueResponse.add(new EnterTransactionResponse(false, "Transaction failed", request.get(1)));
													continue;
												}
												// Create payment for all of those charged
												for (Liable user : chargedUsers) {
													if (database.createPayment(tid, user.getUuid(), user.getChargedCut())) {
														sendNotification(this, new Notification(user.getUuid(), Notification.NotificationType.USERPAID, "You paid for " + database.getUserUName(uid) + "'s purchase", "You contributed £" + new BigDecimal(user.getChargedCut()).movePointLeft(2) + " towards " + database.getUserUName(uid) + "'s purchase '" + title + "'", "\"dismiss\""),database);
													} else {
														queueResponse.add(new EnterTransactionResponse(false, "Transaction failed", request.get(1)));
														break;
													}
												}
												String chosenOption = "\"" + String.join(",", chargedUsers.stream().map(user -> database.getUserUName(user.getUuid())).toList());
												String message = "OPTIONSELECTED:1," + chosenOption + "\",\"" + String.join("\", \"", uidsForSpinner.stream().map(uids -> String.join(",", uids.stream().map(database::getUserUName).toList())).toList()) + "\"";
												queueResponse.add(new EnterTransactionResponse(true, message, request.get(1)));
											}
											case ADDBUDGET -> {
												int amount = Integer.parseInt(request.get(3).substring(7));
												int hid = Integer.parseInt(request.get(4).substring(8));
												if (FinanceModel.topUp(uid, hid, amount)) {
													queueResponse.add(new AddBudgetResponse(request.get(1)));
												} else {
													queueResponse.add(new AddBudgetResponse("Budget update failed", request.get(1)));
												}
											}
											case SETPERSONALSETTING -> {
												// Not 100% sure the format of the setting-value pairs
												// Assuming just : separating
												List<String> requestList = request.subList(3, request.size());
												boolean validated = true;
												for (String item : requestList) {
													String[] pair = item.split(":");
													if (pair.length > 2) {
														// Assuming this would happen if they put a ':' in one of the settings
														queueResponse.add(new SetPersonalSettingResponse(false, "Invalid input", request.get(1)));
													}
													if (Objects.equals(pair[0], "NAME")) {
														if (database.getUid(pair[1]) != null) {
															validated = false;  // username not unique
															queueResponse.add(new SetPersonalSettingResponse(false, "Username is not unique", request.get(1)));
															break;
														}
													}
													 else if (!Objects.equals(pair[0],"PASSWORD")) {
														validated = false; // if they try to set something not settable
														queueResponse.add(new SetPersonalSettingResponse(false, "Update failed", request.get(1)));
														break;
													}
												}
												if (!validated) {
													continue;
												}
												for (String item : requestList) {
													String[] pair = item.split(":");
													if (Objects.equals(pair[0], "NAME")) {
														if (!database.setUserUsername(uid,  pair[1].substring(1,pair[1].length()-1))) {
															queueResponse.add(new SetPersonalSettingResponse(false, "Update failed", request.get(1)));
															break;  // I think we should break out as soon as possible - no more changes
														}
													} else if (Objects.equals(pair[0], "PASSWORD")) {
														if (!database.setUserPassword(uid, sha256(pair[1].substring(1,pair[1].length()-1)))) {
															queueResponse.add(new SetPersonalSettingResponse(false, "Update failed", request.get(1)));
															break;
														}
													}
												}
												queueResponse.add(new SetPersonalSettingResponse(true, String.join(",", request.subList(3, request.size())), request.get(1)));
											}
											case NOTIFICATIONRESPONSE -> {
												int nid = Integer.parseInt(request.get(3).substring(15));
												Notification notification = database.getNotification(nid);
												String response = request.get(4).substring(9);  // Should leave response with '"'
												// Check whether this is a valid nid
                                                if (notification == null) {
                                                    queueResponse.add(new NotificationResponseResponse("FAILURE,\"Notification ID not valid\"", request.get(1)));
                                                    continue;
                                                }
												if (notification.uid != uid) {
                                                    queueResponse.add(new NotificationResponseResponse("FAILURE,\"Notifcation is not for this user\"", request.get(1)));
                                                    continue;
                                                }
												switch (notification.type) {
													case GROUPINVITE -> {
														switch (response) {
															case ("\"accept\"") -> {
																String[] options = notification.options.split("\\.");
																String hidOption = options[2].substring(8,options[2].length()-1);
																int hid = Integer.parseInt(hidOption);
																if (!database.deleteInvitesEntry(hid, uid)) {
																	queueResponse.add(new NotificationResponseResponse("FAILURE,\"Database failed to delete invite\"", request.get(1)));
																	continue;
																}
																if (!database.deleteNotificationsEntry(nid)) {
																	queueResponse.add(new NotificationResponseResponse("FAILURE,\"Database failed to delete notification\"", request.get(1)));
																	continue;
																}
																// All conditions have been met so add to group
																if (!database.addToHousehold(uid, hid)) {
																	queueResponse.add(new NotificationResponseResponse("FAILURE,\"Database failed to add to household\"", request.get(1)));
																} else {
																	queueResponse.add(new NotificationResponseResponse("SUCCESS,GROUPID:" + hid, request.get(1)));
																}
															}
															case ("\"dismiss\"") -> {
																String[] options = notification.options.split("\\.");
																String hidOption = options[2].substring(8,options[2].length()-1);
																int hid = Integer.parseInt(hidOption);
																//String options = notification.getOptions();

																if (!database.deleteInvitesEntry(hid, uid)) {
																	queueResponse.add(new NotificationResponseResponse("FAILURE,\"Database failed to delete invite\"", request.get(1)));
																	continue;
																}
																if (!database.deleteNotificationsEntry(nid)) {
																	queueResponse.add(new NotificationResponseResponse("FAILURE,\"Database failed to delete notification\"", request.get(1)));
																} else {
																	queueResponse.add(new NotificationResponseResponse("SUCCESS", request.get(1)));
																}
															}
															default -> queueResponse.add(new NotificationResponseResponse("FAILURE,\"Invalid response\"", request.get(1)));
														}
													}
                                                    case REMOVEDFROMGROUP, USERPAID -> {
                                                        if (!"\"dismiss\"".equals(response)) {
                                                            queueResponse.add(new NotificationResponseResponse("FAILURE,\"Invalid response\"", request.get(1)));
                                                            continue;
                                                        }
                                                        if (!database.deleteNotificationsEntry(nid)) {
                                                            queueResponse.add(new NotificationResponseResponse("FAILURE,\"Database failed to delete notification\"", request.get(1)));
                                                        } else {
                                                            queueResponse.add(new NotificationResponseResponse("SUCCESS", request.get(1)));
                                                        }
                                                    }
                                                }
											}
											case REQUESTNOTIFICATIONS -> {
												List<Notification> notifications = database.getNotifications(uid);
												if (notifications == null) {
													queueResponse.add(new RequestNotificationsResponse("Request to get notifications failed", request.get(1)));
												} else {
													queueResponse.add(new RequestNotificationsResponse(notifications, request.get(1)));
												}
											}
											case VIEWTRANSACTIONS -> {
												List<Transaction> transactions = database.getTransactions(uid);
												if (transactions == null) {
													queueResponse.add(new ViewTransactionsResponse("Failed to fetch transactions", request.get(1)));
												} else {
													queueResponse.add(new ViewTransactionsResponse(transactions, request.get(1)));
												}
											}
											case GETSTATUS -> {
												String username = database.getUserUName(uid);
												List<Integer> groups = database.getAllHouseholds(uid);
												if ((username == null) | (groups == null)) {
													queueResponse.add(new GetStatusResponse(false, "Failed to get status", request.get(1)));
												} else {
													queueResponse.add(new GetStatusResponse(true, "\"" + username + "\",USERID:" + uid + "," + String.join(",", groups.stream().map(g -> g + ",\"" + database.getHouseholdName(g) + "\"").toList()), request.get(1)));
												}
											}
											default -> queueResponse.add(new InvalidFormatResponse("valid request", request));
										}
									} catch (Exception e) {
										e.printStackTrace();
										queueResponse.add(new InvalidFormatResponse("valid request", request));
									}
								}
								default -> queueResponse.add(new InvalidFormatResponse("<REQUEST,...>", request));
							}
						}
					}
				}
			} catch (InterruptedException e) {
				connected = false;
				e.printStackTrace();
			} catch (Exception e) {                                 // just threw this because I didn't know what else to do;
				e.printStackTrace();
			}
		});
		process.setDaemon(true);
		process.start();
	}

	public static void sendNotification(ClientHandler sender, Notification notification, MySqlCon database) {
		if (database.createNotification(notification) != null) {                                // add notification to database
			if (Server.online.containsKey(notification.uid)) {                                       // if recipient is online
				for (ClientHandler clientHandler : Server.online.get(notification.uid)) {
					clientHandler.queueResponse.add(new NotificationResponse(notification));    // add directly to recipient send queue
				}
			}
		} else {
			sender.queueResponse.add(new DebugResponse("Failed to send notification."));        // inform client if notification not added to database
		}
	}
}
