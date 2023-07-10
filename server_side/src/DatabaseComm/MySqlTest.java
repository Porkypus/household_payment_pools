package DatabaseComm;

import server.Transaction;

import java.util.*;

public class MySqlTest {
    public static void main(String[] args) {
        MySqlCon s = new MySqlCon();
        //s.incrementCharged(144,33,100);
        //System.out.println(b);
        //int a = s.createNotification(1,"not1,","test","duda");
        //Notification n = new Notification(122,2,"GROUPINVITE","two"," has removed you from the group '" + "poo" + "'","\"dismiss\".\"hidden:" + 4 + "\"",new Date());
        //int c = s.createNotification(n);

        s.createTransaction("weinerman",2,2,1000);
        //List<Integer> a = s.getPaymentUsers(2);
        List<Transaction> t = s.getTransactions(2);
        for(Transaction tt:t) {
            System.out.println(tt.toString());
        }
        //int b = s.createUser("joe","poo");
        //System.out.println(c);
        //s.deleteUserMembersEntry(21,70);
        //System.out.println(s.getHouseholdName(52));
        //System.out.println(s.getUserUName(258));
        //int a = s.getUserBudget(38,16);
        //System.out.println(c);
        s.close();
    }
}
