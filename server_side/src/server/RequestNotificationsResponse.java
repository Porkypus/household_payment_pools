package server;

import java.util.List;

public class RequestNotificationsResponse extends Response{
    public RequestNotificationsResponse(List<Notification> notifications, String requestID) {
        super("REQUESTNOTIFCATIONS,SUCCESS," + String.join(",", notifications.stream().map(Notification::toString).toList()), requestID);
    }
    public RequestNotificationsResponse(String message, String requestID) {
        super("REQUESTNOTIFCATIONS,FAILURE,\"" + message + "\"", requestID);
    }
}
