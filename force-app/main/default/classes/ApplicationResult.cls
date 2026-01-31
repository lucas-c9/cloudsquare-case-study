public class ApplicationResult {
    @AuraEnabled public Boolean success { get; set; }
    @AuraEnabled public Boolean matchFound { get; set; }
    @AuraEnabled public String leadId { get; set; }
    @AuraEnabled public String opportunityId { get; set; }
    @AuraEnabled public String accountId { get; set; }
    @AuraEnabled public String contactId { get; set; }
    @AuraEnabled public String errorMessage { get; set; }
    @AuraEnabled public String errorType { get; set; }
    
    public ApplicationResult() {
        this.success = false;
        this.matchFound = false;
    }
}