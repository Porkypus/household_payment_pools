package server;

public class HandshakeFailResponse extends Response {
	public HandshakeFailResponse(String message) {
		super("HANDSHAKEFAIL,\"" + message + "\"");
	}
}
