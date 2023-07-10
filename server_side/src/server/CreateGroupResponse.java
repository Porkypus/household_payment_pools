package server;

public class CreateGroupResponse extends Response {
    public CreateGroupResponse(int groupID, String requestID) {
        super("CREATEGROUP,SUCCESS,GROUPID:" + groupID, requestID);
    }
    public CreateGroupResponse(String message, String requestID) {
        super("CREATEGROUP,FAILURE,\"" + message + "\"", requestID);
    }
}
