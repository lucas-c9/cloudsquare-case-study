@isTest
private class ApplicationControllerTest {
    
    @TestSetup
    static void setup() {
        Account testAccount = new Account(
            Name = 'Cloudsquare',
            Federal_Tax_ID__c = '11-22334455'
        );
        insert testAccount;
    }
    
    @isTest
    static void testSuccessfulCommunitySubmission() {
        ApplicationRequest request = new ApplicationRequest();
        request.companyName = 'Company Lead';
        request.email = 'lead@test.com';
        request.phone = '+54-11-2233-4455';
        request.firstName = 'Lionel';
        request.lastName = 'Messi';
        request.federalTaxId = '22-33445566';
        request.annualRevenue = 300000;
        
        Test.startTest();
        ApplicationResult result = ApplicationController.submitApplication(request);
        Test.stopTest();
        
        System.assert(result.success, 'Submission should succeed');
        System.assertNotEquals(null, result.leadId, 'Lead should be created');
        
        Lead createdLead = [
            SELECT Source__c 
            FROM Lead 
            WHERE Id = :result.leadId
        ];
        System.assertEquals(
            ApplicationService.SOURCE_COMMUNITY, 
            createdLead.Source__c,
            'Source should be set to Community'
        );
    }
    
    @isTest
    static void testOpportunityCreationThroughController() {
        ApplicationRequest request = new ApplicationRequest();
        request.companyName = 'Company Opp';
        request.email = 'opp@test.com';
        request.phone = '+54-22-3344-5566';
        request.firstName = 'Diego';
        request.lastName = 'Maradona';
        request.federalTaxId = '11-22334455';
        
        Test.startTest();
        ApplicationResult result = ApplicationController.submitApplication(request);
        Test.stopTest();
        
        System.assert(result.success, 'Submission should succeed');
        System.assert(result.matchFound, 'Match should be found');
        System.assertNotEquals(null, result.opportunityId, 'Opportunity should be created');
    }
    
    @isTest
    static void testControllerErrorHandling() {
        ApplicationRequest request = new ApplicationRequest();
        request.companyName = 'Test';
        
        Test.startTest();
        ApplicationResult result = ApplicationController.submitApplication(request);
        Test.stopTest();
        
        System.assertEquals(false, result.success, 'Should fail validation');
        System.assertNotEquals(null, result.errorMessage, 'Should return error message');
    }
    
    @isTest
    static void testNullRequest() {
        Test.startTest();
        ApplicationResult result = ApplicationController.submitApplication(null);
        Test.stopTest();
        
        System.assertEquals(false, result.success, 'Should fail with null request');
        System.assertNotEquals(null, result.errorMessage, 'Should return error message');
    }
}
