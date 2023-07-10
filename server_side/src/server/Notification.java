package server;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;

public class Notification {
	int nid;
	int uid;
	NotificationType type;
	String title;
	String body;
	String options;
	Date timestamp;
	List<String> items;

	enum NotificationType {
		GROUPINVITE, REMOVEDFROMGROUP, USERPAID
	}

	public Notification(int tuid, NotificationType ttype, String ttitle, String tbody, String toptions) {
		nid = 0;
		uid = tuid;
		type = ttype;
		title = ttitle;
		body = tbody;
		options = toptions;
		timestamp = new Date();
		items = new ArrayList<>();
	}

	public Notification(int tnid, int tuid, String ttype, String ttitle, String tbody, String toptions, Date ttimestamp) {
		nid = tnid;
		uid = tuid;
		type = NotificationType.valueOf(ttype);
		title = ttitle;
		body = tbody;
		options = toptions;
		timestamp = ttimestamp;
		items = new ArrayList<>();
	}

	public int getNid() {
		return nid;
	}

	public int getUid() {
		return uid;
	}

	public String getTitle() {
		return title;
	}

	public String getBody() {
		return body;
	}

	public String getOptions() {
		return options;
	}

	public Date getTimestamp() {
		return timestamp;
	}
	public String getType() {
		return type.toString();
	}

	public List<String> getItems() {
		return items;
	}
	@Override
	public String toString() {
		return type.name() + ",NOTIFICATIONID:" + nid + ",\"" + title + "\",\"" + body + "\",TIMESTAMP:" + (timestamp.getTime()/1000) + "," + options;
	}
}
