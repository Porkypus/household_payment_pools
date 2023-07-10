package server;

public enum Message {
	DEBUG("DEBUG"),
	HOUSEPAYCLIENT("HOUSEPAYCLIENT"),
	HANDSHAKESUCCESSFUL("HANDSHAKESUCCESSFUL"),
	REQUEST("REQUEST"),
	INVALID("INVALID");

	final String string;
	Message(String string) {
		this.string = string;
	}
}
