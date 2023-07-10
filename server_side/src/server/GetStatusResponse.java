package server;

public class GetStatusResponse extends Response{
    public GetStatusResponse(boolean success, String message,String requestID) {
        super("GETSTATUS," + (success ? "SUCCESS," : "FAILURE,")  + message, requestID);
    }
}
