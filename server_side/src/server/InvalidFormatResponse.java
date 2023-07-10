package server;

import java.util.List;

public class InvalidFormatResponse extends DebugResponse {
	InvalidFormatResponse(String expected, List<String> request) {
		super("Expecting: " + expected + ", but got <" + String.join(",", request) + ">");
	}
}
