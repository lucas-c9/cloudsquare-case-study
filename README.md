# Salesforce Application System
This is my use case test for Cloudsquare.

A production-ready Salesforce solution for processing external partner applications through multiple channels (Experience Cloud and REST API), with intelligent account matching and automated lead/opportunity creation.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture & Design](#architecture--design)
- [Key Features](#key-features)
- [Technical Implementation](#technical-implementation)
- [Security Considerations](#security-considerations)
- [Testing Strategy](#testing-strategy)
- [Usage Examples](#usage-examples)
- [Design Tradeoffs](#design-tradeoffs)
- [Future Enhancements](#future-enhancements)

---

## Overview

This solution enables external partners to submit applications into Salesforce through two channels:

1. **Public Experience Cloud Form** - LWC-based web form for manual submissions
2. **REST API Webhook** - Secure endpoint for automated system integrations

The system intelligently matches submissions against existing accounts and creates either:
- **Lead** - When no account match is found
- **Opportunity + Contact** - When an existing account is matched

### Matching Logic Priority

1. **Federal Tax ID** (highest priority) - Exact match on `Federal_Tax_ID__c`
2. **Company Name** (fallback) - Exact match on Account Name

---

## Architecture & Design

### Design Philosophy

This solution follows **Clean Architecture** principles with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────┐
│                   Presentation Layer                    │
│  ┌──────────────────┐        ┌───────────────────────┐  │
│  │  LWC Component   │        │     REST API          │  │
│  │  (UI/Form)       │        │  (Webhook Endpoint)   │  │
│  └──────────────────┘        └───────────────────────┘  │
└─────────────────────┬──────────────────┬────────────────┘
                      │                  │
┌─────────────────────▼──────────────────▼─────────────────┐
│               Controller Layer                           │
│  ┌──────────────────────────────────────────────────┐    │
│  │  ApplicationController                           │    │
│  │  ApplicationAPI                                  │    │
│  └──────────────────────────────────────────────────┘    │
└─────────────────────┬────────────────────────────────────┘
                      │
┌─────────────────────▼─────────────────────────────────────┐
│                 Service Layer                             │
│  ┌──────────────────────────────────────────────────┐     │
│  │  ApplicationService (Business Logic)             │     │
│  │  - Validation                                    │     │
│  │  - Account Matching                              │     │
│  │  - Lead/Opportunity Creation                     │     │
│  └──────────────────────────────────────────────────┘     │
└─────────────────────┬─────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                   Data Layer                                │
│  ┌────────────┐  ┌────────────┐  ┌──────────┐               │
│  │   Lead     │  │ Opportunity│  │ Contact  │               │
│  └────────────┘  └────────────┘  └──────────┘               │
└─────────────────────────────────────────────────────────────┘
```

### Core Components

| Component | Purpose | Pattern |
|-----------|---------|---------|
| `ApplicationService` | Business logic orchestration | Service Layer |
| `ApplicationAPI` | REST endpoint handler | Controller |
| `ApplicationController` | LWC backend | Controller |
| `ApplicationRequest` | Input data structure | DTO |
| `ApplicationResult` | Output data structure | DTO |
| `applicationForm` | Public UI component | LWC |

### Design Patterns Applied

1. **Service Layer Pattern** - Business logic centralized in `ApplicationIntakeService`
2. **Data Transfer Object (DTO)** - Clean data contracts with `ApplicationRequest` and `ApplicationResult`
3. **Strategy Pattern** - Matching logic can be extended with different strategies
4. **Error Handling Pattern** - Custom exceptions with graceful degradation
5. **Separation of Concerns** - Clear boundaries between layers

---

## Key Features

### ✅ Intelligent Matching
- Federal Tax ID matching (priority 1)
- Company name matching (fallback)
- Case-insensitive matching
- Extensible matching strategy

### ✅ Dual Channel Support
- Experience Cloud web form (LWC)
- REST API for external systems
- Consistent processing logic
- Source tracking for analytics

### ✅ Robust Security
- Input validation and sanitization
- SQL injection protection
- XSS attack prevention
- Email domain blacklisting
- Request size limits (DoS protection)
- Suspicious pattern detection

### ✅ Comprehensive Testing
- 100% code coverage
- Unit tests for all scenarios
- Integration tests
- Security vulnerability tests
- Edge case coverage

---

## Technical Implementation

### Custom Fields Required

The following custom fields must be created in your org:

**On Lead:**
- `Federal_Tax_ID__c` (Text, 16) - Stores Federal Tax ID - XX-XXXXXXXXX
- `Source__c` (Picklist) - Values: "Community", "Webhook"

**On Opportunity:**
- `Source__c` (Picklist) - Values: "Community", "Webhook"
- `ContactId` (Lookup to Contact) - Standard field in most orgs

**On Account:**
- `Federal_Tax_ID__c` (Text, 16) - For matching - XX-XXXXXXXXX

### Apex Classes

| Class | Purpose |
|-------|---------|
| `ApplicationService.cls` |Core business logic |
| `ApplicationAPI.cls` | REST API endpoint |
| `ApplicationController.cls` | LWC controller |
| `ApplicationServiceTest.cls` | Service tests |
| `ApplicationAPITest.cls` | API tests |
| `ApplicationControllerTest.cls` | Controller tests |

### LWC Component

**Files:**
- `applicationForm.js` - Component logic
- `applicationForm.html` - Template
- `applicationForm.css` - Styles
- `applicationForm.js-meta.xml` - Metadata

---

## Security Considerations

### Input Validation

```
1. Required field validation
2. Email format validation (regex)
3. Phone number validation
4. Data type validation
5. Field length checks
```

### Attack Protection

| Attack Vector | Protection Mechanism |
|---------------|---------------------|
| SQL Injection | Pattern detection + parameterized SOQL |
| XSS | HTML entity detection |
| DoS | Request size limits (10KB) |
| CSRF | Salesforce platform protection |
| Malicious Input | Suspicious pattern scanning |
| Spam Domains | Email domain blacklist |

### Logging & Monitoring

```
- Suspicious request patterns
- Validation failures
- Blacklisted domains (filled with test data)
- Excessive data values
```
---

## Testing Strategy

### Test Scenarios Covered

#### Success Scenarios
1. ✅ Lead creation (no account match)
2. ✅ Opportunity creation (Tax ID match)
3. ✅ Opportunity creation (name match)
4. ✅ Minimum valid data submission
5. ✅ Full data submission

#### Failure Scenarios
1. ✅ Missing required fields
2. ✅ Invalid email format
3. ✅ Database errors
4. ✅ Null request handling
5. ✅ Malformed JSON
6. ✅ Request body too large
7. ✅ SQL injection attempts
8. ✅ XSS attempts
9. ✅ Blacklisted domains
10. ✅ Excessive values

---

## Usage Examples

### Example 1: Community Form Submission

1. User navigates to public form
2. Fills in required information
3. Clicks "Submit Application"
4. System shows success message with reference ID

### Example 2: Webhook Integration (cURL)

```bash
curl --request POST \
--url https://orgfarm-d24f37f61c-dev-ed.develop.my.salesforce.com/services/apexrest/application/v1/submit \
-H 'Content-Type: application/json' \
-d '{
    "companyName": "API Opp 2",
    "email": "apiopp2@test.com",
    "phone": "5555672",
    "firstName": "Existing",
    "lastName": "ApiOpp 2",
    "federalTaxId": "11-123123123"
}'
```

**Response (Lead Created):**
```json
{
	"success": true,
	"message": "Application processed - Lead created",
	"data": {
		"recordType": "Lead",
		"leadId": "00Qfj000009fwAvEAI",
		"matchFound": "false"
	}
}
```

**Response (Opportunity Created):**
```json
{
	"success": true,
	"message": "Application processed - Opportunity created",
	"data": {
		"recordType": "Opportunity",
		"contactId": "003fj00000eITsYAAW",
		"accountId": "001fj00000fX0EXAA0",
		"opportunityId": "006fj000008ttP4AAI",
		"matchFound": "true"
	}
}
```

---

## Design Tradeoffs

### 1. Single Service Class vs Multiple Services

**Decision:** Single `ApplicatioService` class

**Rationale:**
- ✅ Simplicity - One class to maintain
- ✅ Cohesion - Related logic grouped together
- ✅ Easier testing - All business logic in one place
- ❌ Could grow large over time

**Alternative Considered:**
- Separate services for matching, lead creation, opportunity creation
- Would provide better separation but increase complexity for current scope

### 2. Synchronous vs Asynchronous Processing

**Decision:** Synchronous processing

**Rationale:**
- ✅ Immediate feedback to user
- ✅ Simpler error handling
- ✅ Lower complexity
- ❌ Limited to governor limits (150 DML)

**Future Enhancement:**
- For high-volume scenarios, implement queueable processing

### 3. Custom Metadata vs Hard-Coded Security Rules

**Decision:** Hard-coded security rules (for now)

**Rationale:**
- ✅ Faster initial implementation
- ✅ No configuration overhead
- ✅ Version controlled
- ❌ Requires code deployment to change

**Future Enhancement:**
- Move blacklisted domains to Custom Metadata
- Allow admins to configure without code changes

### 4. Platform Events vs Direct Logging

**Decision:** Direct System.debug() logging

**Rationale:**
- ✅ Simpler implementation
- ✅ Available in all orgs
- ✅ No additional setup
- ❌ Not suitable for production monitoring

**Future Enhancement:**
- Implement Platform Events for security monitoring

---

## Future Enhancements

### Not Yet Implemented (Intentionally)

#### 1. **Duplicate Lead Prevention** ⚠️ INTENTIONALLY NOT IMPLEMENTED

**Why:**
This is the most important "not implemented" item because it represents a real production concern.

**The Issue:**
Currently, the system can create duplicate leads if:
- Same person submits the form multiple times
- Application comes in via both webhook and community for same contact
- Similar but not exact company names exist

**Why Not Implemented:**
- SHORT DEVELOPMENT TIME
- Requires decision on deduplication strategy (email? company+email? fuzzy matching?)
- Need to define: Should we update existing lead, create new one, or reject?
- Requires additional fields to track submission timestamps
- Complexity around when to merge vs create new

---

### Other Future Enhancements

#### 1. **Rate Limiting**
- Implement API rate limiting per IP
- Use Platform Cache for tracking
- Prevent abuse and DoS attacks

#### 2. **Advanced Matching**
- Fuzzy matching for company names
- Levenshtein distance algorithm
- Match confidence scoring
- Manual review queue for ambiguous matches

#### 3. **Webhook Signature Verification**
- HMAC signature validation
- Trusted source verification
- Replay attack prevention

#### 4. **Custom Metadata Configuration**
- Blacklisted email domains
- Matching rules priority
- Field mappings
- Validation rules

#### 5. **Platform Events for Monitoring**
```apex
Security_Event__e event = new Security_Event__e(
    Event_Type__c = 'Suspicious_Submission',
    Source_IP__c = req.headers.get('X-Forwarded-For'),
    Details__c = 'SQL injection attempt detected'
);
EventBus.publish(event);
```

#### 6. **Asynchronous Processing**
```apex
public class ApplicatioQueueable implements Queueable {
    private ApplicationRequest request;
    
    public void execute(QueueableContext context) {
        ApplicatioService.processApplication(request);
    }
}
```

**README Developed with readme.so**