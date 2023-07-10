package server;

import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;

import static financialModel.FinanceModel.sha256;

public class Database {
    // defined in protocol
    int createUser(String username, String password){
        return 0; // return id
    }
    int createHousehold(String name, int uid) {
        return 1; // assuming groupID returned, else -1 for failure
    }
    boolean addToHousehold(int uid, int hid) {
        return false;
    }
    void setBudget(int uid, int hid, int budget) {}
    void chargeAmount(int uid, int hid, int amount) {}
    boolean createPayment(int uid, int tid, int amount) {
        return false;
    }
    void spendAmount(int uid, int hid, int amount) {}
    Integer createTransaction(int uid, int hid, int amount) {
        return null;
    }
    boolean addNotifications(int uid, String title, String Body, String options) {
        return true; // return success
    }
    boolean addInvite(int hid, int uid) {
        return true; // return success
    }

    // not yet defined
    int signInUser(String name, String password){
        return 0; // return id
    }
    List<String> getGroupInfo(int groupID) { return new LinkedList<>();}    // ideally returned as a list in form "valuename:value,.."
    List<String> getUserByName(String name) {return new LinkedList<>();}
    int getGroup(int uid) {
        return 0; // this doesn't make sense if a user can be in multiple groups but idk how else to do it
    }
    List<String> getUserByID(int uid) {
        return new LinkedList<>();
    }

    public Integer getUid(String username) {
        return 0;
    }

    public String getUserPassword(Integer uid) {
        return sha256("pass1");
    }

    public String getUserName(int userID) {
        return "";
    }

    public boolean createInvite(int groupID, int recipientID) {
        return true;
    }

    public String getHouseholdName(int groupID) {
        return "";
    }

    public Integer getHouseholdLeader(int groupID) {
        return 0;
    }

    public List<Integer> getAllUsers(int groupID) {
        return new ArrayList<>(List.of(0));
    }

    public Integer getUserBudget(Integer member, int groupID) {
        return 0;
    }

    public boolean setHouseholdName(int groupID, String s) {
        return true;
    }

    public boolean setHouseholdLeader(int groupID, int parseInt) {
        return true;
    }

    public boolean deleteUserMembersEntry(int groupID, int userIDToRemove) {
        return true;
    }

    public boolean setUserUsername(Integer uid, String s) {
        return true;
    }

    public boolean setUserPassword(Integer uid, String s) {
        return true;
    }

    public String getNotificationType(int nid) {
        return null;
    }

    public List<Notification> getNotifications(Integer uid) {
        return new ArrayList<>();
    }

    public List<Transaction> getTransactions(Integer uid) {
    return new ArrayList<>();
    }

    public List<Integer> getAllHouseholds(Integer uid) {
    return new ArrayList<>();
    }

    public boolean createNotification(Notification notification) {
    return true;
    }

    public boolean deleteInvitesEntry(int hid, Integer uid) {
        return true;
    }

    public boolean deleteNotificationsEntry(Integer nid) {
        return true;
    }
}
