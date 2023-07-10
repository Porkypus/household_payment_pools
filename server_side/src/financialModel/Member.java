package financialModel;


public class Member implements Comparable<Member> {

    private final int uuid;
    private int budget;
    private int actualSpend;
    private int charged;

    Member(int uuid, int budget, int actualSpend, int charged) {
        this.uuid = uuid;
        this.budget = budget;
        this.actualSpend = actualSpend;
        this.charged = charged;
    }

    public int getUuid() {
        return uuid;
    }

    public int getBudget() {
        return budget;
    }

    public int getActualSpend() {
        return actualSpend;
    }

    public int getCharged() {
        return charged;
    }

    public Double getKarma() {
        return  (((double) actualSpend + 1)) / ((double) (charged + 1));
    }

    public Double getWorth() {
        return ((double) (charged + 1)) / (((double) actualSpend + 1));
    }

    @Override
    public int compareTo(Member o) {
        return getKarma().compareTo(o.getKarma());
    }
}
