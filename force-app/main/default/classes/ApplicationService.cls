public without sharing class ApplicationService {
    
    public static final String SOURCE_COMMUNITY = 'Community';
    public static final String SOURCE_WEBHOOK = 'Webhook';
    private static final String FIELD_APPLICATION_SOURCE = 'Source__c';
    private static final String FIELD_FEDERAL_TAX_ID = 'Federal_Tax_ID__c';

    private static void assertReadable(Schema.SObjectType sobType, List<Schema.SObjectField> fields) {
        if (!sobType.getDescribe().isAccessible()) {
            throw new ApplicationException('Insufficient access to read ' + String.valueOf(sobType));
        }
        for (Schema.SObjectField aField : fields) {
            if (!aField.getDescribe().isAccessible()) {
                throw new ApplicationException('Insufficient field-level access to read field: ' + aField.getDescribe().getName());
            }
        }
    }
    private static void assertCreatable(Schema.SObjectType sobType, List<Schema.SObjectField> fields) {
        if (!sobType.getDescribe().isCreateable()) {
            throw new ApplicationException('Insufficient access to create ' + String.valueOf(sobType));
        }
        for (Schema.SObjectField aField : fields) {
            if (!aField.getDescribe().isCreateable()) {
                throw new ApplicationException('Insufficient field-level access to create field: ' + aField.getDescribe().getName());
            }
        }
    }
    
    public static ApplicationResult processApplication(ApplicationRequest request) {
        ApplicationResult result = new ApplicationResult();
        
        try {
            validateRequest(request);
            
            Account matchedAccount = findMatchingAccount(request);
            
            if (matchedAccount != null) {
                result = createOpportunityFromMatch(request, matchedAccount);
                result.matchFound = true;
                result.accountId = matchedAccount.Id;
            } else {
                result = createLeadFromRequest(request);
                result.matchFound = false;
            }
            
            result.success = true;
            
        } catch (ApplicationException e) {
            result.success = false;
            result.errorMessage = e.getMessage();
            result.errorType = 'VALIDATION_ERROR';
        } catch (DmlException e) {
            result.success = false;
            result.errorMessage = 'Database error: ' + e.getDmlMessage(0);
            result.errorType = 'DATABASE_ERROR';
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = 'Unexpected error: ' + e.getMessage();
            result.errorType = 'SYSTEM_ERROR';
            System.debug(LoggingLevel.ERROR, 'Application processing failed: ' + e.getStackTraceString());
        }
        
        return result;
    }
    
    private static void validateRequest(ApplicationRequest request) {
        List<String> errors = new List<String>();
        
        if (String.isBlank(request.companyName)) {
            errors.add('Company Name is required');
        }
        
        if (String.isBlank(request.email)) {
            errors.add('Email is required');
        } else if (!isValidEmail(request.email)) {
            errors.add('Invalid email format');
        }
        
        if (String.isBlank(request.phone)) {
            errors.add('Phone is required');
        }
        
        if (String.isBlank(request.firstName)) {
            errors.add('Contact First Name is required');
        }
        
        if (String.isBlank(request.lastName)) {
            errors.add('Contact Last Name is required');
        }
        
        if (String.isBlank(request.source)) {
            errors.add('Application source is required');
        }
        
        if (!errors.isEmpty()) {
            throw new ApplicationException('Validation failed: ' + String.join(errors, '; '));
        }
    }

    private static Boolean isValidEmail(String email) {
        String emailRegex = '^[a-zA-Z0-9._|\\\\%#~`=?&/$^*!}{+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,4}$';
        Pattern pattern = Pattern.compile(emailRegex);
        Matcher matcher = pattern.matcher(email);
        return matcher.matches();
    }

    @TestVisible
    private static Account findMatchingAccount(ApplicationRequest request) {
        Account matchedAccount = null;
        
        if (!Schema.sObjectType.Account.isAccessible()) {
            throw new ApplicationException('Insufficient permissions to access Account records');
        }
        
        if (String.isNotBlank(request.federalTaxId)) {
            String searchFTId = request.federalTaxId.trim();
            assertReadable(
                Account.SObjectType,
                new List<Schema.SObjectField>{
                    Account.Id, Account.Name, Account.Federal_Tax_ID__c
                }
            );
            List<Account> taxIdMatches = [
                SELECT Id, Name, Federal_Tax_ID__c
                FROM Account
                WHERE Federal_Tax_ID__c = :searchFTId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (!taxIdMatches.isEmpty()) {
                return taxIdMatches[0];
            }
        }
        
        if (String.isNotBlank(request.companyName)) {
            assertReadable(
                Account.SObjectType,
                new List<Schema.SObjectField>{ Account.Id, Account.Name }
            );
            List<Account> exactMatches = [
                SELECT Id, Name
                FROM Account
                WHERE Name = :request.companyName
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (!exactMatches.isEmpty()) {
                return exactMatches[0];
            }
            
            String companyNameLower = request.companyName.toLowerCase();
            assertReadable(
                Account.SObjectType,
                new List<Schema.SObjectField>{ Account.Id, Account.Name }
            );
            List<Account> caseInsensitiveMatches = [
                SELECT Id, Name
                FROM Account
                WHERE Name = :request.companyName
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (!caseInsensitiveMatches.isEmpty()) {
                return caseInsensitiveMatches[0];
            }
        }
        
        return null;
    }

    private static ApplicationResult createOpportunityFromMatch(
        ApplicationRequest request, 
        Account matchedAccount
    ) {
        ApplicationResult result = new ApplicationResult();
        
        if (!Schema.sObjectType.Contact.isCreateable()) {
            throw new ApplicationException('Insufficient permissions to create Contact records');
        }
        
        assertCreatable(
            Contact.SObjectType,
            new List<Schema.SObjectField>{
                Contact.FirstName, Contact.LastName, Contact.Email, Contact.Phone, Contact.AccountId
            }
        );
        Contact newContact = new Contact(
            FirstName = request.firstName,
            LastName = request.lastName,
            Email = request.email,
            Phone = request.phone,
            AccountId = matchedAccount.Id
        );
        Database.SaveResult[] contactSr = Database.insert(new List<SObject>{ newContact }, false);
        if (!contactSr[0].isSuccess()) {
            throw new DmlException(contactSr[0].getErrors()[0].getMessage());
        }
        
        if (!Schema.sObjectType.Opportunity.isCreateable()) {
            throw new ApplicationException('Insufficient permissions to create Opportunity records');
        }
        
        assertCreatable(
            Opportunity.SObjectType,
            new List<Schema.SObjectField>{
                Opportunity.Name, Opportunity.AccountId, Opportunity.StageName, Opportunity.CloseDate, Opportunity.LeadSource
            }
        );
        Opportunity newOpp = new Opportunity(
            Name = matchedAccount.Name + ' - New Application - ' + request.source,
            AccountId = matchedAccount.Id,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(30),
            LeadSource = 'Application Intake'
        );
        newOpp.put('ContactId', newContact.Id);
        
        if (request.annualRevenue != null) {
            if (Opportunity.Amount.getDescribe().isCreateable()) {
                newOpp.Amount = request.annualRevenue;
            }
        }
        
        if (Opportunity.SObjectType.getDescribe().isAccessible()) {
            newOpp.put(FIELD_APPLICATION_SOURCE, request.source);
        }
        
        Database.SaveResult[] oppSr = Database.insert(new List<SObject>{ newOpp }, false);
        if (!oppSr[0].isSuccess()) {
            throw new DmlException(oppSr[0].getErrors()[0].getMessage());
        }
        
        result.opportunityId = newOpp.Id;
        result.contactId = newContact.Id;
        
        return result;
    }

    private static ApplicationResult createLeadFromRequest(ApplicationRequest request) {
        ApplicationResult result = new ApplicationResult();
        
        if (!Schema.sObjectType.Lead.isCreateable()) {
            throw new ApplicationException('Insufficient permissions to create Lead records');
        }
        
        assertCreatable(
            Lead.SObjectType,
            new List<Schema.SObjectField>{
                Lead.FirstName, Lead.LastName, Lead.Company, Lead.Email, Lead.Phone, Lead.Status, Lead.LeadSource
            }
        );
        Lead newLead = new Lead(
            FirstName = request.firstName,
            LastName = request.lastName,
            Company = request.companyName,
            Email = request.email,
            Phone = request.phone,
            Status = 'Open - Not Contacted',
            LeadSource = 'Application Intake'
        );
        
        if (request.annualRevenue != null && Lead.AnnualRevenue.getDescribe().isCreateable()) {
            newLead.AnnualRevenue = request.annualRevenue;
        }
        
        if (String.isNotBlank(request.federalTaxId)) {
            Schema.DescribeFieldResult fDesc = ((Schema.SObjectField) Schema.getGlobalDescribe().get('Lead').getDescribe().fields.getMap().get(FIELD_FEDERAL_TAX_ID)).getDescribe();
            if (fDesc != null && fDesc.isCreateable()) {
                newLead.put(FIELD_FEDERAL_TAX_ID, request.federalTaxId);
            }
        }
        
        newLead.put(FIELD_APPLICATION_SOURCE, request.source);
        
        Database.SaveResult[] leadSr = Database.insert(new List<SObject>{ newLead }, false);
        if (!leadSr[0].isSuccess()) {
            throw new DmlException(leadSr[0].getErrors()[0].getMessage());
        }
        
        result.leadId = newLead.Id;
        
        return result;
    }

    
    public class ApplicationException extends Exception {}
}
