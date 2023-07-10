package server;

public class AddBudgetResponse extends Response{
    public AddBudgetResponse(String message, String requestID) {
        super("ADDBUDGET,FAILURE,\"" + message + "\"", requestID);
    }
    public AddBudgetResponse(String requestID) {
        super("ADDBUDGET,SUCCESS", requestID);
    }
}
