@isTest
private class ApplicationAPITest {
    
    @TestSetup
    static void setup() {
        Account testAccount = new Account(
            Name = 'Cloudsquare',
            Federal_Tax_ID__c = '11-22334455'
        );
        insert testAccount;
    }
    
    @isTest
    static void testSuccessfulAPISubmission_Lead() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        String requestBody = JSON.serialize(new Map<String, Object>{
            'companyName' => 'API Company Lead',
            'email' => 'apiLead@test.com',
            'phone' => '+54-11-2233-4455',
            'firstName' => 'API',
            'lastName' => 'LeadUser',
            'federalTaxId' => '22-33445566',
            'annualRevenue' => 100000
        });
        
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
            ApplicationAPI.ApiResponse response = ApplicationAPI.submitApplication();
        Test.stopTest();
        
        System.assertEquals(200, res.statusCode, 'Should return 200 status');
        System.assert(response.success, 'API call should succeed');
        System.assert(response.message.contains('Lead created'), 'Should indicate lead creation');
        System.assertNotEquals(null, response.data.get('leadId'), 'Should return lead ID');
        System.assertEquals('Lead', response.data.get('recordType'), 'Record type should be Lead');
        
        List<Lead> leads = [
            SELECT Id, Source__c 
            FROM Lead 
            WHERE Email = 'apiLead@test.com'
        ];
        System.assertEquals(1, leads.size(), 'One lead should be created');
        System.assertEquals(ApplicationService.SOURCE_WEBHOOK, leads[0].Source__c, 'Source should be set to Webhook');
    }
    
    @isTest
    static void testSuccessfulAPISubmission_Opportunity() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        String requestBody = JSON.serialize(new Map<String, Object>{
            'companyName' => 'API Company Opp Name',
            'email' => 'apiOpp@apitest.com',
            'phone' => '+54-11-2233-4455',
            'firstName' => 'API',
            'lastName' => 'OppUser',
            'federalTaxId' => '11-22334455'
        });
        
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        ApplicationAPI.ApiResponse response = ApplicationAPI.submitApplication();
        Test.stopTest();
        
        System.assertEquals(200, res.statusCode, 'Should return 200 status');
        System.assert(response.success, 'API call should succeed');
        System.assert(response.message.contains('Opportunity created'), 'Should indicate opportunity creation');
        System.assertNotEquals(null, response.data.get('opportunityId'), 'Should return opportunity ID');
        System.assertEquals('Opportunity', response.data.get('recordType'), 'Record type should be Opportunity');
    }
    
    @isTest
    static void testEmptyRequestBody() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestBody = Blob.valueOf('');
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        ApplicationAPI.ApiResponse response = ApplicationAPI.submitApplication();
        Test.stopTest();
        
        System.assertEquals(400, res.statusCode, 'Should return 400 for empty body');
        System.assertEquals(false, response.success, 'API call should fail');
        System.assert(response.message.contains('required'), 'Should indicate required fields missing');
    }
    
    @isTest
    static void testMalformedJSON() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestBody = Blob.valueOf('{ this is not valid json }');
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        ApplicationAPI.ApiResponse response = ApplicationAPI.submitApplication();
        Test.stopTest();
        
        System.assertEquals(400, res.statusCode, 'Should return 400 for malformed JSON');
        System.assertEquals(false, response.success, 'API call should fail');
        System.assert(response.message.contains('Invalid JSON'), 'Should indicate invalid JSON');
    }
    
    @isTest
    static void testRequestBodyTooLarge() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        String largeBody = 'A'.repeat(15000);
        req.requestBody = Blob.valueOf(largeBody);
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        ApplicationAPI.ApiResponse response = ApplicationAPI.submitApplication();
        Test.stopTest();
        
        System.assertEquals(400, res.statusCode, 'Should return 400 for large body');
        System.assertEquals(false, response.success, 'API call should fail');
        System.assert(response.message.contains('too large'), 'Should indicate body is too large');
    }
    
    @isTest
    static void testSQLInjectionAttempt() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        String requestBody = JSON.serialize(new Map<String, Object>{
            'companyName' => 'Test\'; DROP TABLE Account; --',
            'email' => 'testMalicious@test.com',
            'phone' => '+54-11-2233-4455',
            'firstName' => 'SELECT * FROM',
            'lastName' => 'Account'
        });
        
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        ApplicationAPI.ApiResponse response = ApplicationAPI.submitApplication();
        Test.stopTest();
        
        System.assertEquals(400, res.statusCode, 'Should reject suspicious patterns');
        System.assertEquals(false, response.success, 'API call should fail');
        System.assert(response.message.contains('Invalid or suspicious'), 'Should indicate invalid or suspicious input');
    }
    
    @isTest
    static void testXSSAttempt() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        String requestBody = JSON.serialize(new Map<String, Object>{
            'companyName' => '<script>alert("XSS")</script>',
            'email' => 'testScript@test.com',
            'phone' => '+54-11-2233-4455',
            'firstName' => 'Test',
            'lastName' => 'ScriptUser'
        });
        
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        ApplicationAPI.ApiResponse response = ApplicationAPI.submitApplication();
        Test.stopTest();
        
        System.assertEquals(400, res.statusCode, 'Should return 400 for XSS attempt');
        System.assertEquals(false, response.success, 'API call should fail');
    }
    
    @isTest
    static void testBlacklistedEmailDomain() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        String requestBody = JSON.serialize(new Map<String, Object>{
            'companyName' => 'Blacklist Company',
            'email' => 'spam@tempmail.com',
            'phone' => '+54-11-2233-4455',
            'firstName' => 'Test',
            'lastName' => 'BlacklistUser'
        });
        
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        ApplicationAPI.ApiResponse response = ApplicationAPI.submitApplication();
        Test.stopTest();
        
        System.assertEquals(400, res.statusCode, 'Should return 400 for blacklisted email domain');
        System.assertEquals(false, response.success, 'API call should fail');
    }
    
    @isTest
    static void testExcessiveRevenueValue() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        String requestBody = JSON.serialize(new Map<String, Object>{
            'companyName' => 'Test Company',
            'email' => 'test@company.com',
            'phone' => '+54-11-2233-4455',
            'firstName' => 'Test',
            'lastName' => 'ExcessiveRevenueUser',
            'annualRevenue' => 9999999999999.99
        });
        
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        ApplicationAPI.ApiResponse response = ApplicationAPI.submitApplication();
        Test.stopTest();
        
        System.assertEquals(400, res.statusCode, 'Should return 400 for excessive revenue value');
        System.assertEquals(false, response.success, 'API call should fail');
    }
    
    @isTest
    static void testValidationErrorStatus() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        String requestBody = JSON.serialize(new Map<String, Object>{
            'companyName' => 'Test Company'
        });
        
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        ApplicationAPI.ApiResponse response = ApplicationAPI.submitApplication();
        Test.stopTest();
        
        System.assertEquals(400, res.statusCode, 'Validation errors should return 400');
        System.assertEquals(false, response.success, 'API call should fail');
    }
    
    @isTest
    static void testFlexiblePayloadStructure() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        String requestBody = JSON.serialize(new Map<String, Object>{
            'companyName' => 'Flexible Corp',
            'email' => 'flex@corp.com',
            'phone' => '+54-11-2233-4455',
            'firstName' => 'Flex',
            'lastName' => 'User',
            'federalTaxId' => '33-3333333'
        });
        
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        ApplicationAPI.ApiResponse response = ApplicationAPI.submitApplication();
        Test.stopTest();
        
        System.assertEquals(200, res.statusCode, 'Should return 200 for valid payload');
        System.assert(response.success, 'API call should succeed');
    }
}
