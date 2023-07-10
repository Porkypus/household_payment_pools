package server;

public class SetPersonalSettingResponse extends Response {
    public SetPersonalSettingResponse(boolean success, String message, String requestID) {
        super("SETPERSONALSETTING," + (success ? "SUCCESS" : "FAILURE") + ",\"" + message + "\"", requestID);
    }
}
