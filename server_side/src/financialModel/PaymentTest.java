package financialModel;

import DatabaseComm.MySqlCon;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;

// Dummy class which simulates a single household with x members and n transactions between 0.00 and 30.00 performed by a random member of the group
public class PaymentTest {
    public static void main(String[] args) {

        MySqlCon database = new MySqlCon();

        int leader = database.createUser( "Johnz", "Dudebase");
        int hid = database.createHousehold("Test", leader);
        int user1 = database.createUser( "Johnz", "Dudebase");
        int user2 = database.createUser("Johnz", "Dudebase");
        int user3 = database.createUser( "Johnz", "Dudebase");
        int user4 = database.createUser( "Johnz", "Dudebase");
        int user5 = database.createUser( "Johnz", "Dudebase");

        database.addToHousehold(leader, hid);
        database.addToHousehold(user1, hid);
        database.addToHousehold(user2, hid);
        database.addToHousehold(user3, hid);
        database.addToHousehold(user4, hid);
        database.addToHousehold(user5, hid);

        database.setBudget(leader, hid, 10000);
        database.setBudget(user1, hid, 10000);
        database.setBudget(user2, hid, 10000);
        database.setBudget(user3, hid, 10000);
        database.setBudget(user4, hid, 10000);
        database.setBudget(user5, hid, 10000);


        List<Integer> uids = new ArrayList<>();
        uids.add(leader);
        uids.add(user1);
        uids.add(user2);
        uids.add(user3);
        uids.add(user4);
        uids.add(user5);

        // Random transaction generation
        Random rand = new Random();
        int n = 1000;
        for (int i = 0; i < n; i++) {
            FinanceModel.pay(uids.get(rand.nextInt(6)), hid , rand.nextInt(30));
        }

        List<Integer> uuids = database.getAllUsers(hid);
        List<Member> household = new ArrayList<>();
        for (Integer member : uuids) {
            household.add(new Member(member, database.getUserBudget(member, hid), database.getUserSpent(member, hid), database.getUserCharged(member, hid)));
        }

        for (Member member : household) {
            System.out.println("Name: " + member.getUuid());
            System.out.println("Budget: " + member.getBudget());
            System.out.println("Actual Spent: " + member.getActualSpend());
            System.out.println("Charged: " + member.getCharged());
            System.out.println("% difference: " + Math.abs(( member.getActualSpend() - member.getCharged())/ 100.0) + "%");
            System.out.println();
        }
        database.close();

        System.out.println(FinanceModel.sha256("Hello"));
    }
}
