package financialModel;

public class Liable {
    // Return uuids of liable people, chosen persons, amounts charged
    private int uuid;
    private int chargedCut;

    Liable(int uuid, int chargedCut){
        this.uuid = uuid;
        this.chargedCut = chargedCut;
    }

    public int getUuid() {
        return uuid;
    }

    public int getChargedCut() {
        return chargedCut;
    }
}
