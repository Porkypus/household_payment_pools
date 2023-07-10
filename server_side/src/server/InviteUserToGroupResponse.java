package server;

public class InviteUserToGroupResponse extends Response {
	public InviteUserToGroupResponse(String requestID) {
		super("INVITEUSERTOGROUP,SUCCESS", requestID);
	}
	public InviteUserToGroupResponse(String message, String requestID) {
		super("INVITEUSERTOGROUP,FAILURE,\"" + message + "\"", requestID);
	}
}
