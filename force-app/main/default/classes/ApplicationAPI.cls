@RestResource(urlMapping='/application/v1/submit')
global with sharing class ApplicationAPI {
    @HttpPost
    global static ApiResponse submitApplication() {
        ApiResponse response = new ApiResponse();
        
        try {
            RestRequest req = RestContext.request;
            RestResponse res = RestContext.response;
            
            String requestBody = req.requestBody.toString();
            
            if (String.isBlank(requestBody)) {
                res.statusCode = 400;
                response.success = false;
                response.message = 'Request body is required';
                return response;
            }
            
            if (requestBody.length() > 10000) {
                res.statusCode = 400;
                response.success = false;
                response.message = 'Request body too large';
                return response;
            }
            
            ApplicationRequest request;
            try {
                Map<String, Object> dataMap = (Map<String, Object>) JSON.deserializeUntyped(requestBody);
                request = ApplicationRequest.fromMap(dataMap);
            } catch (JSONException e) {
                res.statusCode = 400;
                response.success = false;
                response.message = 'Invalid JSON format';
                return response;
            }
            
            request.source = ApplicationService.SOURCE_WEBHOOK;
            
            if (!isValidWebhookRequest(request)) {
                res.statusCode = 400;
                response.success = false;
                response.message = 'Invalid or suspicious request data';
                logSecurityEvent('Suspicious webhook request blocked', requestBody);
                return response;
            }
            
            ApplicationResult result = ApplicationService.processApplication(request);
            
            if (result.success) {
                res.statusCode = 200;
                response.success = true;
                response.message = result.matchFound ? 
                    'Application processed - Opportunity created' : 
                    'Application processed - Lead created';
                response.data = buildResponseData(result);
            } else {
                if (result.errorType == 'VALIDATION_ERROR') {
                    res.statusCode = 400;
                } else {
                    res.statusCode = 500;
                }
                response.success = false;
                response.message = result.errorMessage;
            }
            
        } catch (Exception e) {
            RestContext.response.statusCode = 500;
            response.success = false;
            response.message = 'An error occurred processing your request';
            System.debug(LoggingLevel.ERROR, 'API Error: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
        
        return response;
    }

    private static Boolean isValidWebhookRequest(ApplicationRequest request) {
        List<String> fieldsToCheck = new List<String>{
            request.companyName,
            request.email,
            request.phone,
            request.firstName,
            request.lastName,
            request.federalTaxId
        };
        
        for (String field : fieldsToCheck) {
            if (String.isNotBlank(field) && containsSuspiciousPatterns(field)) {
                return false;
            }
        }
        
        if (String.isNotBlank(request.email)) {
            String domain = request.email.substringAfter('@');
            if (isBlacklistedDomain(domain)) {
                return false;
            }
        }
        
        if (String.isNotBlank(request.phone) && request.phone.length() > 20) {
            return false;
        }
        
        if (request.annualRevenue != null && request.annualRevenue > 999999999999.99) {
            return false;
        }
        
        return true;
    }

    private static Boolean containsSuspiciousPatterns(String input) {
        String lowerInput = input.toLowerCase();
        
        List<String> suspiciousPatterns = new List<String>{
            'script>', '<script', 'javascript:', 'onerror=', 'onclick=',
            'select * from', 'drop table', 'union select', '--',
            'exec(', 'eval(', '../', '..\\',
            'cmd.exe', '/bin/bash'
        };
        
        for (String pattern : suspiciousPatterns) {
            if (lowerInput.contains(pattern)) {
                return true;
            }
        }
        
        return false;
    }

    private static Boolean isBlacklistedDomain(String domain) {
        Set<String> blacklistedDomains = new Set<String>{
            'tempmail.com',
            'throwaway.email',
            'guerrillamail.com'
        };
        
        return blacklistedDomains.contains(domain.toLowerCase());
    }

    private static Map<String, String> buildResponseData(ApplicationResult result) {
        Map<String, String> data = new Map<String, String>();
        
        data.put('matchFound', String.valueOf(result.matchFound));
        
        if (result.leadId != null) {
            data.put('leadId', result.leadId);
            data.put('recordType', 'Lead');
        }
        
        if (result.opportunityId != null) {
            data.put('opportunityId', result.opportunityId);
            data.put('accountId', result.accountId);
            data.put('contactId', result.contactId);
            data.put('recordType', 'Opportunity');
        }
        
        return data;
    }

    private static void logSecurityEvent(String eventType, String details) {
        System.debug(LoggingLevel.WARN, 'SECURITY EVENT: ' + eventType);
        System.debug(LoggingLevel.WARN, 'Details: ' + details.abbreviate(200));
        
    }

    global class ApiResponse {
        @AuraEnabled global Boolean success { get; set; }
        @AuraEnabled global String message { get; set; }
        @AuraEnabled global Map<String, String> data { get; set; }
        
        global ApiResponse() {
            this.success = false;
            this.data = new Map<String, String>();
        }
    }
}