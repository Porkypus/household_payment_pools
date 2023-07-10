package server;
public class LoginResponse extends Response {
    public LoginResponse(int userID, String requestID) {
        super("LOGIN,SUCCESS,USERID:" + userID, requestID);
    }
    public LoginResponse(String message, String requestID) {
        super("LOGIN,FAILURE,\"" + message + "\"", requestID);
    }
}
