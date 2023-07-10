package server;

public class NotificationResponse extends Response {
	public NotificationResponse(Notification notification) {
		super("NOTIFICATION," +
				notification.type.name() + "," +
				notification.nid + "," +
				notification.title + "," +
				notification.body + "," +
				notification.timestamp + ",\"" +
				String.join("\".\"", notification.items) + "\"");
	}
}
