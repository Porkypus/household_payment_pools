package server;

public class EnterTransactionResponse extends Response {
    public EnterTransactionResponse(boolean success, String message, String requestID) {
        super("ENTERTRANSACTION," + (success ? "SUCCESS," + message : "FAILURE,\"" + message + "\""), requestID);

    }
}
