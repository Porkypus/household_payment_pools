package server;

public abstract class Response {
    public String string;
    public Response(String message) {
        string = "<" + message + ">";
    }
    public Response(String message, String requestID) {
        string = "<RESPONSE," + requestID + "," + message + ">";
    }
}
