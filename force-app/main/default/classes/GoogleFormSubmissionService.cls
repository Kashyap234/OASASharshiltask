@RestResource(urlMapping='/GoogleFormSubmission/*')
global with sharing class GoogleFormSubmissionService {
    
    global class FormSubmissionResponse {
        public Boolean success;
        public String message;
        public String accountId;
        public String contactId;
        public List<String> errors;
        public List<String> warnings;
        public String processingTime;
        
        public FormSubmissionResponse() {
            this.errors = new List<String>();
            this.warnings = new List<String>();
        }
    }
    
    @HttpPost
    global static FormSubmissionResponse createAccountAndContact() {
        FormSubmissionResponse response = new FormSubmissionResponse();
        DateTime startTime = DateTime.now();
        
        try {
            RestRequest request = RestContext.request;
            String requestBody = request.requestBody.toString();
            
            System.debug('=== Google Form Submission Processing Started ===');
            System.debug('Request Body: ' + requestBody);
            
            // Validate request body
            if (String.isBlank(requestBody)) {
                throw new GoogleFormException('Empty request body received');
            }
            
            Map<String, Object> formData;
            try {
                formData = (Map<String, Object>) JSON.deserializeUntyped(requestBody);
            } catch (Exception e) {
                throw new GoogleFormException('Invalid JSON format: ' + e.getMessage());
            }
            
            Map<String, Object> accountDataMap = (Map<String, Object>) formData.get('accountData');
            Map<String, Object> contactDataMap = (Map<String, Object>) formData.get('contactData');
            
            // Validate that we have at least some data
            if ((accountDataMap == null || accountDataMap.isEmpty()) && 
                (contactDataMap == null || contactDataMap.isEmpty())) {
                throw new GoogleFormException('No account or contact data provided');
            }
            
            // Create Account if data provided
            Account newAccount;
            if (accountDataMap != null && !accountDataMap.isEmpty()) {
                newAccount = createAccount(accountDataMap, response);
                response.accountId = newAccount.Id;
                System.debug('Created Account: ' + newAccount.Id);
            } else {
                response.warnings.add('No account data provided - account creation skipped');
            }
            
            // Create Contact if data provided
            Contact newContact;
            if (contactDataMap != null && !contactDataMap.isEmpty()) {
                newContact = createContact(contactDataMap, newAccount?.Id, response);
                response.contactId = newContact.Id;
                System.debug('Created Contact: ' + newContact.Id);
            } else {
                response.warnings.add('No contact data provided - contact creation skipped');
            }
            
            response.success = true;
            response.message = buildSuccessMessage(newAccount != null, newContact != null);
            
        } catch (GoogleFormException e) {
            response.success = false;
            response.message = e.getMessage();
            response.errors.add(e.getMessage());
            System.debug('GoogleForm Error: ' + e.getMessage());
            
        } catch (DmlException e) {
            response.success = false;
            response.message = 'Database error occurred';
            for (Integer i = 0; i < e.getNumDml(); i++) {
                String dmlError = 'Record ' + i + ': ' + e.getDmlMessage(i);
                response.errors.add(dmlError);
                System.debug('DML Error: ' + dmlError);
            }
            
        } catch (Exception e) {
            response.success = false;
            response.message = 'An unexpected error occurred: ' + e.getMessage();
            response.errors.add(e.getMessage());
            System.debug('General Error: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
        }
        
        // Calculate processing time
        DateTime endTime = DateTime.now();
        Long processingTimeMs = endTime.getTime() - startTime.getTime();
        response.processingTime = processingTimeMs + 'ms';
        
        System.debug('=== Processing completed in ' + response.processingTime + ' ===');
        System.debug('Response: ' + JSON.serialize(response));
        
        return response;
    }
    
    private static Account createAccount(Map<String, Object> accountDataMap, FormSubmissionResponse response) {
        Account newAccount = new Account();
        
        // Set required Name field with fallback
        String accountName = (String) accountDataMap.get('Name');
        if (String.isBlank(accountName)) {
            accountName = (String) accountDataMap.get('Company');
            if (String.isBlank(accountName)) {
                accountName = 'Google Form Submission - ' + DateTime.now().format('yyyy-MM-dd HH:mm:ss');
                response.warnings.add('No account name provided - using default name');
            }
        }
        newAccount.Name = accountName;
        
        // Set other fields
        Integer fieldsSet = setObjectFields(newAccount, accountDataMap, 'Account', response);
        System.debug('Account fields set: ' + fieldsSet);
        
        // Insert account
        insert newAccount;
        return newAccount;
    }
    
    private static Contact createContact(Map<String, Object> contactDataMap, String accountId, FormSubmissionResponse response) {
        Contact newContact = new Contact();
        
        // Link to account if provided
        if (String.isNotBlank(accountId)) {
            newContact.AccountId = accountId;
        }
        
        // Set required LastName field with fallback
        String lastName = (String) contactDataMap.get('LastName');
        if (String.isBlank(lastName)) {
            lastName = (String) contactDataMap.get('Name');
            if (String.isBlank(lastName)) {
                lastName = 'Google Form Contact';
                response.warnings.add('No last name provided - using default name');
            }
        }
        newContact.LastName = lastName;
        
        // Set other fields
        Integer fieldsSet = setObjectFields(newContact, contactDataMap, 'Contact', response);
        System.debug('Contact fields set: ' + fieldsSet);
        
        // Insert contact
        insert newContact;
        return newContact;
    }
    
    private static Integer setObjectFields(SObject obj, Map<String, Object> dataMap, String objectType, FormSubmissionResponse response) {
        if (dataMap == null || dataMap.isEmpty()) return 0;
        
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectType);
        Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
        
        Integer fieldsSetCount = 0;
        List<String> skippedFields = new List<String>();
        
        for (String fieldName : dataMap.keySet()) {
            Object fieldValue = dataMap.get(fieldName);
            
            // Skip null or empty values
            if (fieldValue == null || String.valueOf(fieldValue).trim() == '') {
                continue;
            }
            
            // Check if field exists on object
            Schema.SObjectField fieldToken = fieldMap.get(fieldName);
            if (fieldToken == null) {
                skippedFields.add(fieldName);
                System.debug('Field not found on ' + objectType + ': ' + fieldName);
                continue;
            }
            
            Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
            
            // Check field permissions
            if (!fieldDescribe.isUpdateable() && !fieldDescribe.isCreateable()) {
                skippedFields.add(fieldName + ' (not writable)');
                System.debug('Field not writable on ' + objectType + ': ' + fieldName);
                continue;
            }
            
            Schema.DisplayType fieldType = fieldDescribe.getType();
            
            try {
                Object convertedValue = convertValueByType(fieldValue, fieldType, fieldDescribe);
                
                // Special handling for Description field - add submission timestamp
                if (fieldName.equalsIgnoreCase('Description') && convertedValue != null) {
                    String description = String.valueOf(convertedValue);
                    if (String.isNotBlank(description)) {
                        convertedValue = description + '\n\nSubmitted via Google Form on ' + 
                                       System.now().format('yyyy-MM-dd HH:mm:ss');
                    }
                }
                
                if (convertedValue != null) {
                    obj.put(fieldName, convertedValue);
                    fieldsSetCount++;
                    System.debug('Set ' + objectType + '.' + fieldName + ' = ' + convertedValue);
                }
                
            } catch (Exception e) {
                skippedFields.add(fieldName + ' (conversion error: ' + e.getMessage() + ')');
                System.debug('Error setting field ' + objectType + '.' + fieldName + ': ' + e.getMessage());
            }
        }
        
        // Add warnings for skipped fields
        if (!skippedFields.isEmpty()) {
            response.warnings.add(objectType + ' fields skipped: ' + String.join(skippedFields, ', '));
        }
        
        return fieldsSetCount;
    }
    
    private static Object convertValueByType(Object value, Schema.DisplayType fieldType, Schema.DescribeFieldResult fieldDescribe) {
        if (value == null) return null;
        
        String stringValue = String.valueOf(value).trim();
        if (String.isBlank(stringValue)) return null;
        
        try {
            switch on fieldType {
                when STRING, TEXTAREA, PHONE, EMAIL, URL {
                    Integer maxLength = fieldDescribe.getLength();
                    if (maxLength > 0 && stringValue.length() > maxLength) {
                        System.debug('Truncating field value from ' + stringValue.length() + ' to ' + maxLength + ' characters');
                        return stringValue.substring(0, maxLength);
                    }
                    return stringValue;
                }
                when PICKLIST {
                    // Validate picklist values
                    List<Schema.PicklistEntry> picklistValues = fieldDescribe.getPicklistValues();
                    for (Schema.PicklistEntry entry : picklistValues) {
                        if (entry.getValue().equalsIgnoreCase(stringValue)) {
                            return entry.getValue();
                        }
                    }
                    // If no exact match found, try partial match
                    for (Schema.PicklistEntry entry : picklistValues) {
                        if (entry.getValue().toLowerCase().contains(stringValue.toLowerCase()) ||
                            stringValue.toLowerCase().contains(entry.getValue().toLowerCase())) {
                            System.debug('Using partial match for picklist: ' + stringValue + ' -> ' + entry.getValue());
                            return entry.getValue();
                        }
                    }
                    System.debug('Invalid picklist value: ' + stringValue + ' for field with values: ' + picklistValues);
                    return null;
                }
                when MULTIPICKLIST {
                    // Handle semicolon or comma separated values
                    List<String> inputValues = stringValue.split('[;,]');
                    List<String> validValues = new List<String>();
                    List<Schema.PicklistEntry> picklistValues = fieldDescribe.getPicklistValues();
                    
                    for (String inputValue : inputValues) {
                        String trimmedValue = inputValue.trim();
                        for (Schema.PicklistEntry entry : picklistValues) {
                            if (entry.getValue().equalsIgnoreCase(trimmedValue)) {
                                validValues.add(entry.getValue());
                                break;
                            }
                        }
                    }
                    
                    return validValues.isEmpty() ? null : String.join(validValues, ';');
                }
                when INTEGER {
                    return Integer.valueOf(stringValue);
                }
                when DOUBLE, PERCENT, CURRENCY {
                    return Decimal.valueOf(stringValue);
                }
                when BOOLEAN {
                    // Handle various boolean representations
                    String lowerValue = stringValue.toLowerCase();
                    if (lowerValue == 'true' || lowerValue == 'yes' || lowerValue == '1' || 
                        lowerValue == 'on' || lowerValue == 'checked') {
                        return true;
                    } else if (lowerValue == 'false' || lowerValue == 'no' || lowerValue == '0' || 
                               lowerValue == 'off' || lowerValue == 'unchecked') {
                        return false;
                    }
                    return Boolean.valueOf(stringValue);
                }
                when DATETIME {
                    try {
                        // Try ISO format first
                        if (stringValue.contains('T')) {
                            return Datetime.valueOf(stringValue.replace('T', ' ').replace('Z', ''));
                        }
                        return Datetime.valueOf(stringValue);
                    } catch (Exception e) {
                        System.debug('DateTime parsing failed for: ' + stringValue);
                        return null;
                    }
                }
                when TIME {
                    try {
                        // Handle HH:MM:SS or HH:MM format
                        List<String> timeParts = stringValue.split(':');
                        Integer hours = Integer.valueOf(timeParts[0]);
                        Integer minutes = timeParts.size() > 1 ? Integer.valueOf(timeParts[1]) : 0;
                        Integer seconds = timeParts.size() > 2 ? Integer.valueOf(timeParts[2]) : 0;
                        Integer milliseconds = 0;
                        
                        return Time.newInstance(hours, minutes, seconds, milliseconds);
                    } catch (Exception e) {
                        System.debug('Time parsing failed for: ' + stringValue);
                        return null;
                    }
                }
                when else {
                    return stringValue;
                }
            }
        } catch (Exception e) {
            System.debug('Error converting value "' + stringValue + '" to type ' + fieldType + ': ' + e.getMessage());
            return null;
        }
    }
    
    private static String buildSuccessMessage(Boolean accountCreated, Boolean contactCreated) {
        List<String> messages = new List<String>();
        
        if (accountCreated && contactCreated) {
            messages.add('Successfully created Account and Contact records');
        } else if (accountCreated) {
            messages.add('Successfully created Account record');
        } else if (contactCreated) {
            messages.add('Successfully created Contact record');
        } else {
            messages.add('No records created - insufficient data provided');
        }
        
        return String.join(messages, '. ');
    }
    
    // Custom exception class for better error handling
    public class GoogleFormException extends Exception {}

    
    private static Map<String, Object> getObjectFieldInfo(String objectType) {
        Map<String, Object> fieldInfo = new Map<String, Object>();
        
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectType);
        Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
        
        for (String fieldName : fieldMap.keySet()) {
            Schema.SObjectField field = fieldMap.get(fieldName);
            Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
            
            // Only include createable/updateable fields
            if (fieldDescribe.isCreateable() || fieldDescribe.isUpdateable()) {
                Map<String, Object> fieldDetails = new Map<String, Object>();
                fieldDetails.put('label', fieldDescribe.getLabel());
                fieldDetails.put('type', String.valueOf(fieldDescribe.getType()));
                fieldDetails.put('required', fieldDescribe.isNillable() == false);
                fieldDetails.put('length', fieldDescribe.getLength());
                
                // Add picklist values if applicable
                if (fieldDescribe.getType() == Schema.DisplayType.PICKLIST || 
                    fieldDescribe.getType() == Schema.DisplayType.MULTIPICKLIST) {
                    List<String> picklistValues = new List<String>();
                    for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
                        if (entry.isActive()) {
                            picklistValues.add(entry.getValue());
                        }
                    }
                    fieldDetails.put('picklistValues', picklistValues);
                }
                
                fieldInfo.put(fieldName, fieldDetails);
            }
        }
        
        return fieldInfo;
    }
}