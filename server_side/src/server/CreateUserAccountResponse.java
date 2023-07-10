package server;
public class CreateUserAccountResponse extends Response{
    public CreateUserAccountResponse(int userID, String requestID) {
        super("CREATEUSERACCOUNT,SUCCESS,USERID:" + userID + ",", requestID);
    }
    public CreateUserAccountResponse(String message, String requestID) {
        super("CREATEUSERACCOUNT,FAILURE,\"" + message + "\"", requestID);
    }
}
