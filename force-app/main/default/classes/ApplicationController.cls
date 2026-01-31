public with sharing class ApplicationController {
    @AuraEnabled
    public static ApplicationResult submitApplication(ApplicationRequest request) {
        try {
            request.source = ApplicationService.SOURCE_COMMUNITY;
            
            ApplicationResult result = ApplicationService.processApplication(request);
            
            return result;
            
        } catch (Exception e) {
            ApplicationResult errorResult = new ApplicationResult();
            errorResult.success = false;
            errorResult.errorMessage = e.getMessage();
            
            System.debug(LoggingLevel.ERROR, 'Controller Error: ' + e.getMessage());
            
            return errorResult;
        }
    }
}