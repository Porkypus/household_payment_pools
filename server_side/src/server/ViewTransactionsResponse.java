package server;

import java.util.List;

public class ViewTransactionsResponse extends Response{
    public ViewTransactionsResponse(List<Transaction> transactions, String requestID) {
        super("VIEWTRANSACTIONS,SUCCESS," + String.join(",", transactions.stream().map(Object::toString).toList()), requestID);
    }
    public ViewTransactionsResponse(String message, String requestID) {
        super("VIEWTRANSACTIONS,FAILURE,\"" + message + "\"", requestID);
    }
}
