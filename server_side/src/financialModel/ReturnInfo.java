package financialModel;

import java.util.ArrayList;
import java.util.List;

public class ReturnInfo {

    private final int payer;
    private final int paid;
    private final int hid;
    private final List<Liable> liables;
    private final List<List<Integer>> uuids;
    private final String status;

    ReturnInfo(int payer, int hid, int paid, List<Liable> liables, List<List<Integer>> uuids, String status) {
        this.payer = payer;
        this.paid = paid;
        this.hid = hid;
        this.liables = liables;
        this.uuids = uuids;
        this.status = status;
    }

    // Return uuid of payer
    public int getPayer() {
        return payer;
    }

    // Return amount to be paid in transaction by payer
    public int getPaid() {
        return paid;
    }

    public int getHid() {
        return hid;
    }

    // Return list of members who got charged i.e. the info about selected option
    public List<Liable> getLiables() {
        return liables;
    }

    // Return uuids of members of selected option
    public List<Integer> getLiablesUuids() {
        List<Integer> uuids = new ArrayList<>();
        for (Liable liable : liables) {
            uuids.add(liable.getUuid());
        }
        return uuids;
    }

    // Return list of options, where each option is a list of uuids
    public List<List<Integer>> getUuids() {
        return uuids;
    }

    public String getStatus() {
        return status;
    }

    @Override
    public String toString() {
        return "{Info object, payer:"+payer+", paid:"+paid+", hid"+hid+", liables:"+liables.toString()+", uuids:"+uuids.toString()+", status:"+status+"}";
    }

}
