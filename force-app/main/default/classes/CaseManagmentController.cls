public class CaseManagmentController {
    @InvocableMethod(label='Case Status' description='Return Case Status')
    public static List<String> getStatus(List<String> caseNumber){
        List<Case> cases = [Select Id, Status from Case where CaseNumber = :caseNumber[0] limit 1];
        
        if(cases.size() > 0){
            return new List<String> {cases[0].status};
		} else {
            return new List<String> {'Case Number is not valid'};
		}
    }
}