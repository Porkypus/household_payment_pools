package server;

public class DebugResponse extends Response {
	DebugResponse(String message) {
		super("DEBUG,\"" + message + "\"");
	}
}
