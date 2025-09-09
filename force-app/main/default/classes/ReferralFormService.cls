@RestResource(urlMapping='/ReferralForm/*')
global with sharing class ReferralFormService {
    
    global class FormSubmissionResponse {
        public Boolean success;
        public String message;
        public String referralFormId;
        public String studentDataId;
        public String schoolId;
        public Boolean studentDataCreated;
        public Boolean studentDataUpdated;
        public Boolean schoolCreated;
        public Boolean duplicateDeleted; // NEW: Track if duplicate was deleted
        public String deletedDuplicateId; // NEW: ID of deleted duplicate record
        public List<String> errors;
        public List<String> warnings;
        public String processingTime;
        
        public FormSubmissionResponse() {
            this.errors = new List<String>();
            this.warnings = new List<String>();
            this.studentDataCreated = false;
            this.studentDataUpdated = false;
            this.schoolCreated = false;
            this.duplicateDeleted = false; // NEW: Initialize duplicate deleted flag
        }
        
        // Method to convert to Map for Aura compatibility
        public Map<String, Object> toMap() {
            Map<String, Object> resultMap = new Map<String, Object>();
            resultMap.put('success', this.success);
            resultMap.put('message', this.message);
            resultMap.put('referralFormId', this.referralFormId);
            resultMap.put('studentDataId', this.studentDataId);
            resultMap.put('schoolId', this.schoolId);
            resultMap.put('studentDataCreated', this.studentDataCreated);
            resultMap.put('studentDataUpdated', this.studentDataUpdated);
            resultMap.put('schoolCreated', this.schoolCreated);
            resultMap.put('duplicateDeleted', this.duplicateDeleted); // NEW
            resultMap.put('deletedDuplicateId', this.deletedDuplicateId); // NEW
            resultMap.put('errors', this.errors);
            resultMap.put('warnings', this.warnings);
            resultMap.put('processingTime', this.processingTime);
            return resultMap;
        }
    }
    
    // Constants for record types
    private static final String STUDENT_RECORD_TYPE = 'Student';
    private static final String INDIVIDUAL_ADULT_RECORD_TYPE = 'Individual_Adult';
    
    // Original REST endpoint method (kept for backward compatibility)
    @HttpPost
    global static FormSubmissionResponse createReferralForm() {
        try {
            RestRequest request = RestContext.request;
            String requestBody = request.requestBody.toString();
            
            if (String.isBlank(requestBody)) {
                throw new ReferralFormException('Empty request body received');
            }
            
            Map<String, Object> formData;
            try {
                formData = (Map<String, Object>) JSON.deserializeUntyped(requestBody);
            } catch (Exception e) {
                throw new ReferralFormException('Invalid JSON format: ' + e.getMessage());
            }
            
            return createReferralFormFromJsonInternal(JSON.serialize(formData));
            
        } catch (Exception e) {
            FormSubmissionResponse errorResponse = new FormSubmissionResponse();
            errorResponse.success = false;
            errorResponse.message = 'An unexpected error occurred: ' + e.getMessage();
            errorResponse.errors.add(e.getMessage());
            System.debug('General Error: ' + e.getMessage());
            return errorResponse;
        }
    }
    
    // Aura-compatible method that returns Map
    @AuraEnabled
    public static Map<String, Object> createReferralFormFromJson(String jsonData) {
        FormSubmissionResponse response = createReferralFormFromJsonInternal(jsonData);
        return response.toMap();
    }
    
    // NEW: Method to create referral form and delete duplicate
    @AuraEnabled
    public static Map<String, Object> createReferralFormAndDeleteDuplicate(String jsonData, String duplicateRecordId) {
        FormSubmissionResponse response = createReferralFormFromJsonInternal(jsonData);
        
        // If the referral form was created successfully and we have a duplicate record ID to delete
        if (response.success && String.isNotBlank(duplicateRecordId)) {
            try {
                // Delete the duplicate referral record
                Duplicate_Referral__c duplicateToDelete = new Duplicate_Referral__c(Id = duplicateRecordId);
                delete duplicateToDelete;
                
                response.duplicateDeleted = true;
                response.deletedDuplicateId = duplicateRecordId;
                response.message += ' Duplicate record has been automatically deleted.';
                response.warnings.add('Duplicate Referral record (' + duplicateRecordId + ') was automatically deleted after creating new record.');
                
                System.debug('Successfully deleted Duplicate_Referral__c record: ' + duplicateRecordId);
                
            } catch (DmlException e) {
                // Don't fail the entire operation if duplicate deletion fails
                response.warnings.add('Warning: Could not delete duplicate record (' + duplicateRecordId + '): ' + e.getDmlMessage(0));
                System.debug('Failed to delete Duplicate_Referral__c record: ' + e.getDmlMessage(0));
            } catch (Exception e) {
                // Don't fail the entire operation if duplicate deletion fails
                response.warnings.add('Warning: Unexpected error deleting duplicate record: ' + e.getMessage());
                System.debug('Unexpected error deleting Duplicate_Referral__c record: ' + e.getMessage());
            }
        }
        
        return response.toMap();
    }
    
    // Internal method that does the actual work and returns FormSubmissionResponse
    // Updated createReferralFormFromJsonInternal method in ReferralFormService
    private static FormSubmissionResponse createReferralFormFromJsonInternal(String jsonData) {
        FormSubmissionResponse response = new FormSubmissionResponse();
        DateTime startTime = DateTime.now();
        
        try {
            System.debug('JSON Data: ' + jsonData);
            
            if (String.isBlank(jsonData)) {
                throw new ReferralFormException('Empty JSON data provided');
            }
            
            Map<String, Object> formData;
            try {
                formData = (Map<String, Object>) JSON.deserializeUntyped(jsonData);
            } catch (Exception e) {
                throw new ReferralFormException('Invalid JSON format: ' + e.getMessage());
            }
            
            // Check if duplicate check should be bypassed
            Boolean bypassDuplicateCheck = formData.containsKey('bypassDuplicateCheck') ? 
                (Boolean) formData.get('bypassDuplicateCheck') : false;
            
            Map<String, Object> referralFormDataMap = (Map<String, Object>) formData.get('referralFormData');
            
            if (referralFormDataMap == null || referralFormDataMap.isEmpty()) {
                throw new ReferralFormException('No referral form data provided');
            }
            
            if ('Student or Family'.equals((String)referralFormDataMap.get('What_type_of_referral_is_this__c'))) {
                
                Id recordTypeId = getRecordTypeId(STUDENT_RECORD_TYPE);
                if (recordTypeId != null) {
                    referralFormDataMap.put('RecordTypeId', recordTypeId);
                }

                // Handle Student record type
                String schoolId = handleSchoolLookupOrCreation(referralFormDataMap, response);
                String studentDataId = handleStudentDataLookupOrCreation(referralFormDataMap, response, schoolId);
                
                if (studentDataId != null) {
                    referralFormDataMap.put('Student_Data__c', studentDataId);
                    response.studentDataId = studentDataId;
                }
            } else if ('Individual Adult and no students'.equals((String)referralFormDataMap.get('What_type_of_referral_is_this__c'))) {
                
                // Only check for duplicates if bypass flag is not set
                if (!bypassDuplicateCheck && handleDuplicateReferral(referralFormDataMap, jsonData, response)) {
                    return response;
                }

                Id recordTypeId = getRecordTypeId(INDIVIDUAL_ADULT_RECORD_TYPE);

                if (recordTypeId != null) {
                    referralFormDataMap.put('RecordTypeId', recordTypeId);
                }

                String schoolId = handleSchoolLookupOrCreation(referralFormDataMap, response);
                if (schoolId != null) {
                    referralFormDataMap.put('School__c', schoolId);
                    response.schoolId = schoolId;
                }
            }
            
            Referral_Form__c newReferralForm = createReferralFormRecord(referralFormDataMap, response);
            response.referralFormId = newReferralForm.Id;
            System.debug('Created ReferralForm: ' + newReferralForm.Id);
            
            response.success = true;
            if (bypassDuplicateCheck) {
                response.message = 'Successfully created Referral Form record (duplicate check bypassed)';
                response.warnings.add('Duplicate check was bypassed - new record created despite potential duplicate');
            } else {
                response.message = 'Successfully created Referral Form record';
            }
            
        } catch (ReferralFormException e) {
            response.success = false;
            response.message = e.getMessage();
            response.errors.add(e.getMessage());
            System.debug('ReferralForm Error: ' + e.getMessage());
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
    
    // Overloaded method that accepts Map directly - also returns Map for Aura compatibility
    @AuraEnabled
    public static Map<String, Object> createReferralFormFromMap(Map<String, Object> formData) {
        if (formData == null || formData.isEmpty()) {
            FormSubmissionResponse errorResponse = new FormSubmissionResponse();
            errorResponse.success = false;
            errorResponse.message = 'Empty form data provided';
            errorResponse.errors.add('Form data map is null or empty');
            return errorResponse.toMap();
        }
        
        String jsonData = JSON.serialize(formData);
        FormSubmissionResponse response = createReferralFormFromJsonInternal(jsonData);
        return response.toMap();
    }

    private static Boolean handleDuplicateReferral(Map<String, Object> referralFormDataMap, String rawRequestBody, FormSubmissionResponse response) {
        try {
            if (referralFormDataMap == null || referralFormDataMap.isEmpty()) {
                return false;
            }

            String phone = referralFormDataMap.containsKey('ParentGuardianAdultPhoneNumber__c')
                ? String.valueOf(referralFormDataMap.get('ParentGuardianAdultPhoneNumber__c')).trim()
                : null;
            String email = referralFormDataMap.containsKey('ParentGuardianAdultEmail__c')
                ? String.valueOf(referralFormDataMap.get('ParentGuardianAdultEmail__c')).trim()
                : null;

            // Handle empty strings as null
            if (phone == '') phone = null;
            if (email == '') email = null;

            if (phone == null && email == null) {
                return false;
            }

            Decimal phoneAsNumber = Decimal.valueOf(phone);

            Datetime sixMonthsAgo = Datetime.now().addMonths(-6);

            // Build dynamic SOQL query
            String soqlQuery = 'SELECT Id FROM Referral_Form__c WHERE CreatedDate >= :sixMonthsAgo';

            List<String> conditions = new List<String>();
            if (phone != null) {
                conditions.add('ParentGuardianAdultPhoneNumber__c = :phoneAsNumber');
            }
            if (email != null) {
                conditions.add('ParentGuardianAdultEmail__c = :email');
            }

            if (!conditions.isEmpty()) {
                soqlQuery += ' AND (' + String.join(conditions, ' OR ') + ')';
            }
            soqlQuery += ' LIMIT 1';

            List<Referral_Form__c> existing = Database.query(soqlQuery);

            if (!existing.isEmpty()) {
                try {
                    Duplicate_Referral__c dup = new Duplicate_Referral__c();
                    dup.Referral_Form__c = existing[0].Id;
                    dup.JSON_Data__c = rawRequestBody;
                    insert dup;
                } catch (DmlException dmle) {
                    System.debug('Failed to insert Duplicate_Referral__c: ' + dmle.getDmlMessage(0));
                }

                response.success = false;
                response.message = 'Duplicate referral found within last 6 months. Captured in Duplicate_Referral__c.';
                response.warnings.add('Duplicate detected by phone/email within 6 months.');
                return true;
            }

            return false;
        } catch (Exception e) {
            System.debug('Error during duplicate referral handling: ' + e.getMessage());
            return false;
        }
    }
    
    private static Id getRecordTypeId(String recordTypeName) {
        if (String.isBlank(recordTypeName)) {
            return null;
        }
        
        try {
            List<RecordType> recordTypes = [
                SELECT Id, Name 
                FROM RecordType 
                WHERE SObjectType = 'Referral_Form__c' AND DeveloperName = :recordTypeName 
                LIMIT 1
            ];
            
            return recordTypes.isEmpty() ? null : recordTypes[0].Id;
        } catch (Exception e) {
            System.debug('Error retrieving record type: ' + e.getMessage());
            return null;
        }
    }
    
    private static String handleSchoolLookupOrCreation(Map<String, Object> referralFormDataMap, FormSubmissionResponse response) {
        Object schoolNameValue = referralFormDataMap.get('School_Name__c');
        
        if (schoolNameValue == null || String.isBlank(String.valueOf(schoolNameValue))) {
            response.warnings.add('No School Name provided - will create Referral Form without School reference');
            return null;
        }
        
        String schoolNameString = String.valueOf(schoolNameValue).trim();
        System.debug('Looking up School with Name: ' + schoolNameString);
        
        try {
            List<School__c> existingSchools = [
                SELECT Id, SchoolName__c
                FROM School__c 
                WHERE SchoolName__c = :schoolNameString 
                LIMIT 1
            ];
            
            if (existingSchools.isEmpty()) {
                response.warnings.add('School not found: ' + schoolNameString + ' - will create Referral Form without School reference');
                return null;
            }
            
            System.debug('Found existing School: ' + existingSchools[0].Id);
            return existingSchools[0].Id;
            
        } catch (QueryException e) {
            System.debug('Query error when looking up School: ' + e.getMessage());
            response.warnings.add('Error querying School records: ' + e.getMessage());
            return null;
        } catch (DmlException e) {
            System.debug('DML error when creating School: ' + e.getMessage());
            response.errors.add('Failed to create School record: ' + e.getDmlMessage(0));
            return null;
        } catch (Exception e) {
            System.debug('Unexpected error in handleSchoolLookupOrCreation: ' + e.getMessage());
            response.errors.add('Unexpected error handling School lookup/creation: ' + e.getMessage());
            return null;
        }
    }
    
    private static String handleStudentDataLookupOrCreation(Map<String, Object> referralFormDataMap, FormSubmissionResponse response, String schoolId) {
        Object studentIdValue = referralFormDataMap.get('StudentIDNumber__c');
        
        if (studentIdValue == null || String.isBlank(String.valueOf(studentIdValue))) {
            response.warnings.add('No Student ID Number provided - will create Referral Form without Student Data reference');
            return null;
        }
        
        String studentIdString = String.valueOf(studentIdValue).trim();
        System.debug('Looking up Student Data with ID: ' + studentIdString);
        
        try {
            // Convert string to number for query
            Decimal studentIdNumber = Decimal.valueOf(studentIdString);
            
            List<Student_Data__c> existingStudentData = [
                SELECT Id, Name, Student_ID_Number__c, Student_First_Name__c, Student_Last_Name__c,
                       Date_of_Birth__c, Grade__c, Gender__c, School__c
                FROM Student_Data__c 
                WHERE Student_ID_Number__c = :studentIdNumber 
                LIMIT 1
            ];
            
            if (!existingStudentData.isEmpty()) {
                System.debug('Found existing Student Data: ' + existingStudentData[0].Id);
                
                // Update existing student data with new information
                Student_Data__c existingStudent = existingStudentData[0];
                Boolean needsUpdate = updateStudentDataFields(existingStudent, referralFormDataMap, schoolId);
                
                if (needsUpdate) {
                    update existingStudent;
                    response.studentDataUpdated = true;
                    response.warnings.add('Updated existing Student Data record with ID: ' + studentIdString);
                    System.debug('Updated Student Data: ' + existingStudent.Id);
                }
                
                return existingStudent.Id;
            }
            
            // Create new student data if not found
            System.debug('Student Data not found, creating new Student Data record');
            Student_Data__c newStudentData = new Student_Data__c();
            newStudentData.Student_ID_Number__c = studentIdNumber;
            
            // Set fields from form data
            setStudentDataFields(newStudentData, referralFormDataMap, schoolId);
            
            insert newStudentData;
            response.studentDataCreated = true;
            response.warnings.add('New Student Data record created with ID: ' + studentIdString);
            System.debug('Created new Student Data: ' + newStudentData.Id);
            
            return newStudentData.Id;
            
        } catch (QueryException e) {
            System.debug('Query error when looking up Student Data: ' + e.getMessage());
            response.warnings.add('Error querying Student Data records: ' + e.getMessage());
            return null;
        } catch (DmlException e) {
            System.debug('DML error when handling Student Data: ' + e.getMessage());
            response.errors.add('Failed to handle Student Data record: ' + e.getDmlMessage(0));
            return null;
        } catch (Exception e) {
            System.debug('Unexpected error in handleStudentDataLookupOrCreation: ' + e.getMessage());
            response.errors.add('Unexpected error handling Student Data lookup/creation: ' + e.getMessage());
            return null;
        }
    }
    
    private static Boolean updateStudentDataFields(Student_Data__c existingStudent, Map<String, Object> referralFormDataMap, String schoolId) {
        Boolean needsUpdate = false;
        
        // Update First Name if provided and different
        if (referralFormDataMap.get('StudentFirstName__c') != null) {
            String newFirstName = String.valueOf(referralFormDataMap.get('StudentFirstName__c'));
            if (existingStudent.Student_First_Name__c != newFirstName) {
                existingStudent.Student_First_Name__c = newFirstName;
                needsUpdate = true;
            }
        }
        
        // Update Last Name if provided and different
        if (referralFormDataMap.get('StudentLastName__c') != null) {
            String newLastName = String.valueOf(referralFormDataMap.get('StudentLastName__c'));
            if (existingStudent.Student_Last_Name__c != newLastName) {
                existingStudent.Student_Last_Name__c = newLastName;
                needsUpdate = true;
            }
        }
        
        // Update Date of Birth if provided and different
        if (referralFormDataMap.get('DateOfBirth__c') != null) {
            String dobString = String.valueOf(referralFormDataMap.get('DateOfBirth__c'));
            try {
                Date newDob = Date.valueOf(dobString);
                if (existingStudent.Date_of_Birth__c != newDob) {
                    existingStudent.Date_of_Birth__c = newDob;
                    needsUpdate = true;
                }
            } catch (Exception e) {
                System.debug('Could not parse date of birth: ' + dobString);
            }
        }
        
        // Update Grade if provided and different
        if (referralFormDataMap.get('Grade__c') != null) {
            String newGrade = String.valueOf(referralFormDataMap.get('Grade__c'));
            if (existingStudent.Grade__c != newGrade) {
                existingStudent.Grade__c = newGrade;
                needsUpdate = true;
            }
        }
        
        // Update Gender if provided and different
        if (referralFormDataMap.get('StudentGender__c') != null) {
            String newGender = String.valueOf(referralFormDataMap.get('StudentGender__c'));
            if (existingStudent.Gender__c != newGender) {
                existingStudent.Gender__c = newGender;
                needsUpdate = true;
            }
        }
        
        // Update School lookup if provided and different
        if (schoolId != null && existingStudent.School__c != schoolId) {
            existingStudent.School__c = schoolId;
            needsUpdate = true;
        }
        
        return needsUpdate;
    }
    
    private static void setStudentDataFields(Student_Data__c studentData, Map<String, Object> referralFormDataMap, String schoolId) {
        if (referralFormDataMap.get('StudentFirstName__c') != null) {
            studentData.Student_First_Name__c = String.valueOf(referralFormDataMap.get('StudentFirstName__c'));
        }
        if (referralFormDataMap.get('StudentLastName__c') != null) {
            studentData.Student_Last_Name__c = String.valueOf(referralFormDataMap.get('StudentLastName__c'));
        }
        if (referralFormDataMap.get('DateOfBirth__c') != null) {
            String dobString = String.valueOf(referralFormDataMap.get('DateOfBirth__c'));
            try {
                studentData.Date_of_Birth__c = Date.valueOf(dobString);
            } catch (Exception e) {
                System.debug('Could not parse date of birth: ' + dobString);
            }
        }
        if (referralFormDataMap.get('Grade__c') != null) {
            studentData.Grade__c = String.valueOf(referralFormDataMap.get('Grade__c'));
        }
        if (referralFormDataMap.get('StudentGender__c') != null) {
            studentData.Gender__c = String.valueOf(referralFormDataMap.get('StudentGender__c'));
        }
        if (schoolId != null) {
            studentData.School__c = schoolId;
        }
    }
    
    private static void cleanupFormDataForReferralForm(Map<String, Object> referralFormDataMap) {
        // Remove fields that are used for lookups but not direct fields on Referral_Form__c
        System.debug('Form data keys before cleanup: ' + referralFormDataMap.keySet());
        
        // Remove student-specific fields that are handled separately
        referralFormDataMap.remove('StudentIDNumber__c');
        referralFormDataMap.remove('StudentFirstName__c');
        referralFormDataMap.remove('StudentLastName__c');
        referralFormDataMap.remove('DateOfBirth__c');
        referralFormDataMap.remove('Grade__c');
        referralFormDataMap.remove('StudentGender__c');
        
        // Remove school-specific fields that are handled separately
        referralFormDataMap.remove('School_Name__c');
        referralFormDataMap.remove('School_District__c');
        referralFormDataMap.remove('School_Address__c');
        
        System.debug('Form data keys after cleanup: ' + referralFormDataMap.keySet());
    }
    
    private static Referral_Form__c createReferralFormRecord(Map<String, Object> referralFormDataMap, FormSubmissionResponse response) {
        Referral_Form__c newReferralForm = new Referral_Form__c();
        
        Integer fieldsSet = setObjectFields(newReferralForm, referralFormDataMap, 'Referral_Form__c', response);
        System.debug('ReferralForm fields set: ' + fieldsSet);
        
        insert newReferralForm;
        return newReferralForm;
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
    
    public class ReferralFormException extends Exception {}
}