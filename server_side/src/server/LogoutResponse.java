package server;

public class LogoutResponse extends Response{
    public LogoutResponse(boolean success, String requestID) {
        super("LOGOUT," + (success ? "SUCCESS":"FAILURE,\"Expecting: <REQUEST,REQUESTID:num,LOGOUT>, but got more fields.\""), requestID);
    }
}
