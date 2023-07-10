package server;

import java.util.Date;
import java.util.Map;

public class Transaction {
	String title;
	int household;
	int amount;
	int purchaser;
	Date date;
	Map<Integer, Integer> payers;

	public Transaction(String ttitle, int thousehold, int tamount, int tpurchaser, Date tdate, Map<Integer, Integer> tpayers) {
		title = ttitle;
		household = thousehold;
		amount = tamount;
		purchaser = tpurchaser;
		date = tdate;
		payers = tpayers;
	}

	public String toString() {
		return "TRANSACTION,\"" + title + "\",AMOUNT:" + amount + ",PURCHASER:" + purchaser + "," + String.join(",", payers.keySet().stream().map(p -> "PAYER:" + p + ",PAYAMOUNT:" + payers.get(p)).toList());
	}
}
