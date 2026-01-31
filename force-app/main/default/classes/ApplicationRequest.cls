public class ApplicationRequest {
    @AuraEnabled public String companyName { get; set; }
    @AuraEnabled public String email { get; set; }
    @AuraEnabled public String phone { get; set; }
    @AuraEnabled public String firstName { get; set; }
    @AuraEnabled public String lastName { get; set; }
    @AuraEnabled public String source { get; set; }
    @AuraEnabled public String federalTaxId { get; set; }
    @AuraEnabled public Decimal annualRevenue { get; set; }

    public static ApplicationRequest fromJSON(String jsonString) {
        return (ApplicationRequest) JSON.deserialize(jsonString, ApplicationRequest.class);
    }

    public static ApplicationRequest fromMap(Map<String, Object> dataMap) {
        ApplicationRequest request = new ApplicationRequest();
        
        request.companyName = (String) dataMap.get('companyName');
        request.email = (String) dataMap.get('email');
        request.phone = (String) dataMap.get('phone');
        request.firstName = (String) dataMap.get('firstName');
        request.lastName = (String) dataMap.get('lastName');
        request.source = (String) dataMap.get('source');
        
        if (dataMap.containsKey('federalTaxId')) {
            request.federalTaxId = (String) dataMap.get('federalTaxId');
        }
        
        if (dataMap.containsKey('annualRevenue')) {
            Object revenueObj = dataMap.get('annualRevenue');
            if (revenueObj instanceof Decimal) {
                request.annualRevenue = (Decimal) revenueObj;
            } else if (revenueObj instanceof String) {
                try {
                    request.annualRevenue = Decimal.valueOf((String) revenueObj);
                } catch (Exception e) {
                    System.debug(LoggingLevel.WARN, 'Invalid annualRevenue format: ' + revenueObj);
                }
            }
        }
        
        return request;
    }
}
