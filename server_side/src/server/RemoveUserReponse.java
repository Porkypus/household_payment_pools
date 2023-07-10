package server;

public class RemoveUserReponse extends Response{
    public RemoveUserReponse(String requestID) {
        super("REMOVEUSER,SUCCESS", requestID);
    }
    public RemoveUserReponse(String message, String requestID) {
        super("REMOVEUSER,FAILURE,\"" + message + "\"", requestID);
    }
}
