package financialModel;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Random;

import DatabaseComm.MySqlCon;

public class FinanceModel {

    // Method for splitting a transaction among most liable household members
    public static synchronized ReturnInfo pay(int uuid, int hid, int amount) {

        // Connect to database
        MySqlCon database = new MySqlCon();

        int rem = amount;

        // Check if household contains member
        if (database.inUserHousehold(uuid, hid)) {
            // Check if member budget too low for payment
            if (amount > ((database.getUserBudget(uuid, hid) + database.getUserCharged(uuid, hid)) - database.getUserSpent(uuid, hid))) {
                System.out.println("Your current balance does not have the required funds for this transaction.");
                database.close();
                return new ReturnInfo(0, 0, 0, null, null, "FAILURE");
            }

            // Cast household as a list of Member objects
            List<Integer> uuids = database.getAllUsers(hid);
            List<Member> household = new ArrayList<>();
            for (Integer member : uuids) {
                household.add(new Member(member, database.getUserBudget(member, hid), database.getUserSpent(member, hid), database.getUserCharged(member, hid)));

            }

            // Sort household by karma from highest to lowest
            household.sort(Collections.reverseOrder());

            // Compute total karma of n most liable members
            double total = 0;
            Random rand = new Random();

            // n is number of people who get charged
            int n = rand.nextInt(1,3);

            for (int i = 0; i < n; i++) {
                Member member = household.get(i);
                total += member.getKarma();
            }

            List<List<Integer>> chosenNames = new ArrayList<>();

            // for-loop filling in 5 remaining options
            for (int j = 0; j < 5; j++) {
                // x is how many members will be in option
                int x = rand.nextInt(1,3);
                List<Integer> option = new ArrayList<>();
                // Helper code to randomly choose members from household with no duplicates
                List<Integer> numbers = new ArrayList<>();
                for (int i = 0; i < household.size(); i++)
                    numbers.add(i);
                Collections.shuffle(numbers);

                // Add x members to option
                for (int k = 0; k < x; k++) {
                    int index = numbers.remove(0);
                    option.add(household.get(index).getUuid());
                }
                chosenNames.add(option);
            }

            List<Liable> liables = new ArrayList<>();

            // Divide amount among liable members proportional to their respective karma
            for (int i = 0; i < n; i++) {
                Member member = household.get(i);
                int cut = (int) Math.floor(amount * (member.getKarma() / total));

                // Check if household members have enough balance for transaction, otherwise charge from own account
                if (member.getBudget() - cut < 0) {
                    liables.add(new Liable(uuid, amount));
                    database.setBudget(uuid, hid, database.getUserBudget(uuid, hid) - amount);
                    database.incrementCharged(uuid, hid, amount);
                    database.close();
                    return new ReturnInfo(uuid, hid, amount, liables, chosenNames, "SUCCESS");
                }
            }

            for (int i = 0; i < n; i++) {
                Member member = household.get(i);
                int cut = (int) Math.floor(amount * (member.getKarma() / total));
                rem -= cut;

                // Add remainder to the least liable of the most liable members
                if (i == n - 1) {
                    cut += rem;
                }
                if (cut != 0) {
                    Liable liable = new Liable(member.getUuid(), cut);
                    liables.add(liable);
                }

                // Update budget and charged amount of liable members
                database.setBudget(member.getUuid(), hid, member.getBudget() - cut);
                database.incrementCharged(member.getUuid(), hid, cut);
            }



            // Increment payer's actual spending
            database.incrementActualSpend(uuid, hid, amount);
            database.close();
            return new ReturnInfo(uuid, hid, amount, liables, chosenNames, "SUCCESS");
        } else {
            System.out.println("This member does not belong to that household");
            database.close();
            return new ReturnInfo(0, 0, 0, null, null, "FAILURE");
        }
    }

    /*
    public static Map<Integer, Integer> returnExpectedCuts(int uuid, int hid, int amount){

        MySqlCon database = new MySqlCon();

        if (database.inUserHousehold(uuid, hid)) {
            // Check if member budget too low for payment
            if (amount > database.getUserBudget(uuid, hid)) {
                System.out.println("Your current balance does not have the required funds for this transaction.");
                database.close();
                return null;
            }

            List<Integer> uuids = database.getAllUsers(hid);
            List<Member> household = new ArrayList<>();
            for (Integer member : uuids) {
                if (member != uuid) {
                    household.add(new Member(member, database.getUserBudget(member, hid), database.getUserSpent(member, hid), database.getUserCharged(member, hid)));
                }
            }

            int total = 0;
            int rem = amount;
            for (Member member : household) {
                total += member.getKarma();
            }

            Map<Integer, Integer> result = new HashMap<>();

            int i = 0;
            for (Member member : household) {
                int cut = (int) Math.floor(amount * (member.getKarma() / total));
                rem -= cut;
                if (i == (household.size() - 1)) {
                    cut += rem;
                }
                result.put(member.getUuid(), cut);
            }
            return result;
        } else {
            System.out.println("This member does not belong to that household");
            database.close();
            return null;
        }
    }

     */


    public static synchronized boolean topUp(int uuid, int hid, int amount) {

        // Connect to database
        MySqlCon database = new MySqlCon();

        if (database.inUserHousehold(uuid, hid)) {
            database.setBudget(uuid, hid, database.getUserBudget(uuid, hid) + amount);
            database.close();
            return true;
        } else {
            System.out.println("This member does not belong to that household");
            database.close();
            return false;
        }

    }


    /*
    public static void leave(int uuid, int hid) {

        // Connect to database
        MySqlCon database = new MySqlCon();

        if (database.inUserHousehold(uuid, hid)) {
            int actualSpent = database.getUserSpent(uuid, hid);
            int charged = database.getUserCharged(uuid, hid);

            List<Integer> uuids = database.getAllUsers(hid);
            List<Member> household = new ArrayList<>();
            for (Integer member : uuids) {
                if (member != uuid) {
                    household.add(new Member(member, database.getUserBudget(member, hid), database.getUserSpent(member, hid), database.getUserCharged(member, hid)));
                }
            }

            if (actualSpent > charged) {
                int surplus = actualSpent - charged;
                if (surplus > database.getUserBudget(uuid, hid)) {
                    System.out.println("Cannot withdraw until user has settled debt");
                    database.close();
                    return;
                }
                int rem = surplus;
                database.setBudget(uuid, hid, database.getUserBudget(uuid, hid) - surplus);

                // Cast household as a list of Member objects

                Collections.sort(household);

                // Compute total karma
                double total = 0;
                for (Member member : household) {
                    total += member.getWorth();
                }

                int i = 0;
                for (Member member : household) {
                    int cut = (int) Math.floor(surplus * (member.getWorth() / total));
                    rem -= cut;

                    if (i == household.size() - 1) {
                        cut += rem;
                    }
                    i++;
                    database.setBudget(member.getUuid(), hid, member.getBudget() + cut);
                }
            }

            if (charged > actualSpent) {
                int surplus = charged - actualSpent;
                int rem = surplus;

                // Sort household by karma from highest to lowest
                household.sort(Collections.reverseOrder());

                // Compute total karma of n most liable members
                double total = 0;
                for (Member member : household) {
                    total += member.getKarma();
                }

                // Divide amount among liable members proportional to their respective karma
                int i = 0;
                for (Member member : household) {
                    int cut = (int) Math.floor(surplus * (member.getKarma() / total));
                    rem -= cut;

                    // Add remainder to the least liable of the most liable members
                    if (i == household.size() - 1) {
                        cut += rem;
                    }
                    i++;

                    if (member.getBudget() - cut < 0) {
                        System.out.println("The household cannot currently pay you back");
                        database.close();
                        return;
                    }

                    // Update budget and charged amount of liable members
                    database.setBudget(member.getUuid(), hid, member.getBudget() - cut);
                    database.incrementCharged(member.getUuid(), hid, cut);
                }
            }
            database.deleteUserMembersEntry(hid, uuid);
        } else {
            System.out.println("This member does not belong to that household");
        }
        database.close();
    }

     */
    public static String sha256(final String base) {
        try{
            final MessageDigest digest = MessageDigest.getInstance("SHA-256");
            final byte[] hash = digest.digest(base.getBytes(StandardCharsets.UTF_8));
            final StringBuilder hexString = new StringBuilder();
            for (byte b : hash) {
                final String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1)
                    hexString.append('0');
                hexString.append(hex);
            }
            return hexString.toString();
        } catch(Exception ex){
            throw new RuntimeException(ex);
        }
    }


}
