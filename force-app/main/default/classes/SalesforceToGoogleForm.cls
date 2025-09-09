@RestResource(urlMapping='/ConsentForm/*')
global with sharing class SalesforceToGoogleForm {
    
    global class FormSubmissionResponse {
        public Boolean success;
        public String message;
        public String consentFormId;
        public String studentId;
        public Boolean studentCreated;
        public List<String> errors;
        public List<String> warnings;
        public String processingTime;
        
        public FormSubmissionResponse() {
            this.errors = new List<String>();
            this.warnings = new List<String>();
            this.studentCreated = false;
        }
    }
    
    @HttpPost
    global static FormSubmissionResponse createConsentForm() {
        FormSubmissionResponse response = new FormSubmissionResponse();
        DateTime startTime = DateTime.now();
        
        try {
            RestRequest request = RestContext.request;
            String requestBody = request.requestBody.toString();
            
            System.debug('Request Body: ' + requestBody);
            
            if (String.isBlank(requestBody)) {
                throw new GoogleFormException('Empty request body received');
            }
            
            Map<String, Object> formData;
            try {
                formData = (Map<String, Object>) JSON.deserializeUntyped(requestBody);
            } catch (Exception e) {
                throw new GoogleFormException('Invalid JSON format: ' + e.getMessage());
            }
            
            Map<String, Object> consentFormDataMap = (Map<String, Object>) formData.get('consentFormData');
            
            if (consentFormDataMap == null || consentFormDataMap.isEmpty()) {
                throw new GoogleFormException('No consent form data provided');
            }

            String studentId = handleStudentLookup(consentFormDataMap, response);
            if (studentId != null) {
                consentFormDataMap.put('Student__c', studentId);
                consentFormDataMap.remove('Student_ID'); 
                response.studentId = studentId;
            }
            
            ConsentForm__c newConsentForm = createConsentForm(consentFormDataMap, response);
            response.consentFormId = newConsentForm.Id;
            System.debug('Created ConsentForm: ' + newConsentForm.Id);
            
            response.success = true;
            response.message = 'Successfully created ConsentForm record';
            
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
        
        DateTime endTime = DateTime.now();
        Long processingTimeMs = endTime.getTime() - startTime.getTime();
        response.processingTime = processingTimeMs + 'ms';
        
        System.debug('=== Processing completed in ' + response.processingTime + ' ===');
        System.debug('Response: ' + JSON.serialize(response));
        
        return response;
    }
    
    private static String handleStudentLookup(Map<String, Object> consentFormDataMap, FormSubmissionResponse response) {
        Object studentIdValue = consentFormDataMap.get('Student_ID');
        
        if (studentIdValue == null || String.isBlank(String.valueOf(studentIdValue))) {
            response.warnings.add('No Student_ID provided - ConsentForm will be created without Student reference');
            return null;
        }
        
        String studentIdString = String.valueOf(studentIdValue).trim();
        System.debug('Looking up Student with ID: ' + studentIdString);
        
        try {
            List<Student__c> existingStudents = [
                SELECT Id, Name, Student_ID__c 
                FROM Student__c 
                WHERE Student_ID__c = :studentIdString 
                LIMIT 1
            ];
            
            if (!existingStudents.isEmpty()) {
                System.debug('Found existing Student: ' + existingStudents[0].Id);
                return existingStudents[0].Id;
            }
            
            System.debug('Student not found, creating new Student record');
            Student__c newStudent = new Student__c();
            newStudent.Student_ID__c = studentIdString;
            
            insert newStudent;
            response.studentCreated = true;
            response.warnings.add('New Student record created with ID: ' + studentIdString);
            System.debug('Created new Student: ' + newStudent.Id);
            
            return newStudent.Id;
            
        } catch (QueryException e) {
            System.debug('Query error when looking up Student: ' + e.getMessage());
            response.warnings.add('Error querying Student records: ' + e.getMessage());
            return null;
        } catch (DmlException e) {
            System.debug('DML error when creating Student: ' + e.getMessage());
            response.errors.add('Failed to create Student record: ' + e.getDmlMessage(0));
            return null;
        } catch (Exception e) {
            System.debug('Unexpected error in handleStudentLookup: ' + e.getMessage());
            response.errors.add('Unexpected error handling Student lookup: ' + e.getMessage());
            return null;
        }
    }
    
    private static ConsentForm__c createConsentForm(Map<String, Object> consentFormDataMap, FormSubmissionResponse response) {
        ConsentForm__c newConsentForm = new ConsentForm__c();
        
        Integer fieldsSet = setObjectFields(newConsentForm, consentFormDataMap, 'ConsentForm__c', response);
        System.debug('ConsentForm fields set: ' + fieldsSet);
        
        insert newConsentForm;
        return newConsentForm;
    }
    
    private static Integer setObjectFields(SObject obj, Map<String, Object> dataMap, String objectType, FormSubmissionResponse response) {
        if (dataMap == null || dataMap.isEmpty()) return 0;
        
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectType);
        Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
        
        Integer fieldsSetCount = 0;
        List<String> skippedFields = new List<String>();
        
        for (String fieldName : dataMap.keySet()) {
            Object fieldValue = dataMap.get(fieldName);
            
            if (fieldValue == null || String.valueOf(fieldValue).trim() == '') {
                continue;
            }
            
            Schema.SObjectField fieldToken = fieldMap.get(fieldName);
            if (fieldToken == null) {
                skippedFields.add(fieldName);
                System.debug('Field not found on ' + objectType + ': ' + fieldName);
                continue;
            }
            
            Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
            
            if (!fieldDescribe.isUpdateable() && !fieldDescribe.isCreateable()) {
                skippedFields.add(fieldName + ' (not writable)');
                System.debug('Field not writable on ' + objectType + ': ' + fieldName);
                continue;
            }
            
            Schema.DisplayType fieldType = fieldDescribe.getType();
            
            try {
                Object convertedValue = convertValueByType(fieldValue, fieldType, fieldDescribe);
                
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
                when REFERENCE {
                    if (stringValue.length() == 15 || stringValue.length() == 18) {
                        return stringValue;
                    }
                    System.debug('Invalid ID format for reference field: ' + stringValue);
                    return null;
                }
                when PICKLIST {
                    List<Schema.PicklistEntry> picklistValues = fieldDescribe.getPicklistValues();
                    for (Schema.PicklistEntry entry : picklistValues) {
                        if (entry.getValue().equalsIgnoreCase(stringValue)) {
                            return entry.getValue();
                        }
                    }
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
                        if (stringValue.contains('T')) {
                            return Datetime.valueOf(stringValue.replace('T', ' ').replace('Z', ''));
                        }
                        return Datetime.valueOf(stringValue);
                    } catch (Exception e) {
                        System.debug('DateTime parsing failed for: ' + stringValue);
                        return null;
                    }
                }
                when DATE {
                    try {
                        return Date.valueOf(stringValue);
                    } catch (Exception e) {
                        System.debug('Date parsing failed for: ' + stringValue);
                        return null;
                    }
                }
                when TIME {
                    try {
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
    
    public class GoogleFormException extends Exception {}
    
    private static Map<String, Object> getObjectFieldInfo(String objectType) {
        Map<String, Object> fieldInfo = new Map<String, Object>();
        
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectType);
        Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
        
        for (String fieldName : fieldMap.keySet()) {
            Schema.SObjectField field = fieldMap.get(fieldName);
            Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
            
            if (fieldDescribe.isCreateable() || fieldDescribe.isUpdateable()) {
                Map<String, Object> fieldDetails = new Map<String, Object>();
                fieldDetails.put('label', fieldDescribe.getLabel());
                fieldDetails.put('type', String.valueOf(fieldDescribe.getType()));
                fieldDetails.put('required', fieldDescribe.isNillable() == false);
                fieldDetails.put('length', fieldDescribe.getLength());
                
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