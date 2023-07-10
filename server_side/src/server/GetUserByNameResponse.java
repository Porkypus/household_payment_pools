package server;

public class GetUserByNameResponse extends Response {
    public GetUserByNameResponse(int uid, String name, String requestID) {
        super("GETUSERBYNAME,SUCCESS" + ",\"" + name + "\",USERID:" + uid, requestID);
    }
    public GetUserByNameResponse(String message, String requestID) {
        super("GETUSERBYNAME,FAILURE,\"" + message + "\"", requestID);
    }
}
