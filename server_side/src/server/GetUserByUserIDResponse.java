package server;

public class GetUserByUserIDResponse extends Response {
	public GetUserByUserIDResponse(int uid, String name, String requestID) {
		super("GETUSERBYUSERID,SUCCESS,\"" + name + "\",USERID:" + uid, requestID);
	}
	public GetUserByUserIDResponse(String message, String requestID) {
		super("GETUSERBYUSERID,FAILURE,\"" + message + "\"", requestID);
	}
}
