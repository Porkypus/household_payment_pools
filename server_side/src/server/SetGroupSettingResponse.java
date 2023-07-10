package server;

public class SetGroupSettingResponse extends Response{
    public SetGroupSettingResponse(boolean success, String message, String requestID) {
        super("SETGROUPSETTING," + (success ? "SUCCESS," : "FAILURE,")  + message, requestID);
    }
}
