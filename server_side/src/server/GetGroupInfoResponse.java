package server;

public class GetGroupInfoResponse extends Response {
    public GetGroupInfoResponse(boolean success, String message, String requestID) {
        super("GETGROUPINFO," + (success ? "SUCCESS," + message : "FAILURE,\"" + message + "\""), requestID);
    }
}
