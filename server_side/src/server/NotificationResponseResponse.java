package server;

public class NotificationResponseResponse extends Response{
    public NotificationResponseResponse(String message, String requestID) {
        super("NOTIFICATIONRESPONSE," + message, requestID);
    }
}
